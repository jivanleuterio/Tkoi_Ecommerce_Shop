-- Tkoi 24-hour return window and returned-product review cleanup.
-- Run after order_aftercare.sql, 03_product_reviews.sql, and 05_seller_wallet.sql.
-- Additive and safe to run twice.

-- The buyer has 24 hours from completion/receipt to create a return request.
-- completed_at is set when mark_order_received changes the order to completed.
-- updated_at is a compatibility fallback for orders completed before migration 05.
create or replace function public.request_order_return(
  p_order_id uuid,
  p_reason text,
  p_details text
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_return_id uuid;
  v_completed_at timestamptz;
begin
  if p_reason not in (
    'Fish arrived unhealthy','Wrong fish received','Item damaged in transit',
    'Order incomplete','Other'
  ) then raise exception 'Choose a valid return reason.'; end if;
  if char_length(trim(coalesce(p_details,''))) not between 10 and 1000
     or coalesce(p_details,'')~'[<>]' then
    raise exception 'Describe the problem using 10 to 1000 characters.';
  end if;

  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.buyer_id<>auth.uid() then
    raise exception 'Order not found.';
  end if;
  if v_order.status<>'completed' then
    raise exception 'Receive the order before requesting a return.';
  end if;

  v_completed_at:=coalesce(
    v_order.completed_at,v_order.updated_at,v_order.created_at
  );
  if now()>=v_completed_at+interval '1 day' then
    raise exception 'The 24-hour return window for this order has closed.';
  end if;

  insert into public.order_returns(
    order_id,buyer_id,seller_id,shop_id,reason,details
  ) values(
    p_order_id,v_order.buyer_id,v_order.seller_id,v_order.shop_id,
    p_reason,trim(p_details)
  )
  on conflict(order_id) do update set
    reason=excluded.reason,details=excluded.details,status='requested'
  where public.order_returns.status in ('rejected','cancelled')
  returning id into v_return_id;

  if v_return_id is null then
    raise exception 'This order already has a return request or was returned.';
  end if;
  return v_return_id;
end; $$;

-- Once the seller confirms the returned fish was received, remove both the
-- legacy order review and all product-level reviews for that order. Review
-- image metadata cascades from product_reviews.
create or replace function public.remove_reviews_for_returned_order()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('received','resolved')
     and old.status is distinct from new.status then
    if to_regclass('public.product_reviews') is not null then
      execute 'delete from public.product_reviews where order_id=$1'
      using new.order_id;
    end if;
    if to_regclass('public.order_reviews') is not null then
      execute 'delete from public.order_reviews where order_id=$1'
      using new.order_id;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists order_returns_remove_reviews on public.order_returns;
create trigger order_returns_remove_reviews
after update of status on public.order_returns
for each row execute function public.remove_reviews_for_returned_order();

-- A completed return must stay unreviewed. This trigger protects both review
-- systems even if an older app calls their existing submission RPCs.
create or replace function public.prevent_review_for_returned_order()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if exists(
    select 1 from public.order_returns r
    where r.order_id=new.order_id and r.status in ('received','resolved')
  ) then
    raise exception 'A returned product cannot be reviewed.';
  end if;
  return new;
end; $$;

do $$
begin
  if to_regclass('public.product_reviews') is not null then
    execute 'drop trigger if exists product_reviews_block_returned_order '
      'on public.product_reviews';
    execute 'create trigger product_reviews_block_returned_order '
      'before insert or update on public.product_reviews for each row '
      'execute function public.prevent_review_for_returned_order()';
  end if;
  if to_regclass('public.order_reviews') is not null then
    execute 'drop trigger if exists order_reviews_block_returned_order '
      'on public.order_reviews';
    execute 'create trigger order_reviews_block_returned_order '
      'before insert or update on public.order_reviews for each row '
      'execute function public.prevent_review_for_returned_order()';
  end if;
end $$;

revoke all on function public.request_order_return(uuid,text,text) from public;
grant execute on function public.request_order_return(uuid,text,text)
  to authenticated;

notify pgrst,'reload schema';
