-- Roll back migration 09 triggers. This does not restore deleted reviews.
drop trigger if exists order_returns_remove_reviews on public.order_returns;
do $$
begin
  if to_regclass('public.product_reviews') is not null then
    execute 'drop trigger if exists product_reviews_block_returned_order '
      'on public.product_reviews';
  end if;
  if to_regclass('public.order_reviews') is not null then
    execute 'drop trigger if exists order_reviews_block_returned_order '
      'on public.order_reviews';
  end if;
end $$;
drop function if exists public.remove_reviews_for_returned_order();
drop function if exists public.prevent_review_for_returned_order();

-- Restore the previous unlimited return-request function.
create or replace function public.request_order_return(
  p_order_id uuid,p_reason text,p_details text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_order public.orders%rowtype; v_return_id uuid;
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
  insert into public.order_returns(
    order_id,buyer_id,seller_id,shop_id,reason,details
  ) values(
    p_order_id,v_order.buyer_id,v_order.seller_id,v_order.shop_id,
    p_reason,trim(p_details)
  ) on conflict(order_id) do update set
    reason=excluded.reason,details=excluded.details,status='requested'
  where public.order_returns.status in ('rejected','cancelled','resolved')
  returning id into v_return_id;
  if v_return_id is null then
    raise exception 'This order already has an active return request.';
  end if;
  return v_return_id;
end; $$;
revoke all on function public.request_order_return(uuid,text,text) from public;
grant execute on function public.request_order_return(uuid,text,text)
  to authenticated;
notify pgrst,'reload schema';
