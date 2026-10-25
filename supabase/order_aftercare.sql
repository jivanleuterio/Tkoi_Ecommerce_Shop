-- Tkoi buyer order aftercare migration.
-- Safe to rerun: keeps existing orders, users, reviews, and return requests.

create table if not exists public.order_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (
    char_length(comment) <= 1000 and comment !~ '[<>]'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  reason text not null check (reason in (
    'Fish arrived unhealthy','Wrong fish received','Item damaged in transit',
    'Order incomplete','Other'
  )),
  details text not null check (
    char_length(trim(details)) between 10 and 1000 and details !~ '[<>]'
  ),
  status text not null default 'requested' check (status in (
    'requested','approved','rejected','received','resolved','cancelled'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists order_reviews_buyer_idx
  on public.order_reviews(buyer_id, created_at desc);
create index if not exists order_reviews_shop_idx
  on public.order_reviews(shop_id, created_at desc);
create index if not exists order_returns_buyer_idx
  on public.order_returns(buyer_id, created_at desc);
create index if not exists order_returns_shop_idx
  on public.order_returns(shop_id, created_at desc);

drop trigger if exists order_reviews_set_updated_at on public.order_reviews;
create trigger order_reviews_set_updated_at before update on public.order_reviews
for each row execute function public.set_updated_at();
drop trigger if exists order_returns_set_updated_at on public.order_returns;
create trigger order_returns_set_updated_at before update on public.order_returns
for each row execute function public.set_updated_at();

alter table public.order_reviews enable row level security;
alter table public.order_returns enable row level security;

revoke all on table public.order_reviews from anon;
revoke all on table public.order_returns from anon;
revoke insert, update, delete on table public.order_reviews from authenticated;
revoke insert, update, delete on table public.order_returns from authenticated;
grant select on table public.order_reviews to authenticated;
grant select on table public.order_returns to authenticated;

drop policy if exists "Order parties view reviews" on public.order_reviews;
create policy "Order parties view reviews" on public.order_reviews
for select to authenticated using (
  buyer_id=auth.uid() or seller_id=auth.uid()
);
drop policy if exists "Order parties view returns" on public.order_returns;
create policy "Order parties view returns" on public.order_returns
for select to authenticated using (
  buyer_id=auth.uid() or seller_id=auth.uid()
);

create or replace function public.mark_order_received(p_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.buyer_id<>auth.uid() then
    raise exception 'Order not found.';
  end if;
  if v_order.status='completed' then return; end if;
  if v_order.status<>'shipped' then
    raise exception 'Only a shipped order can be marked as received.';
  end if;
  update public.orders set status='completed' where id=p_order_id;
end; $$;

-- Only the buyer confirms final receipt. Sellers still manage every delivery
-- step through "shipped" and can cancel eligible COD orders.
create or replace function public.update_order_status(
  p_order_id uuid,
  p_status text
) returns void language plpgsql security definer set search_path=public as $$
declare v_order public.orders%rowtype;
begin
  if p_status not in (
    'pending','confirmed','preparing','ready_for_delivery','shipped','cancelled'
  ) then raise exception 'The buyer confirms when an order is received.'; end if;
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.seller_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status in ('completed','cancelled') then raise exception 'A completed or cancelled order cannot be changed.'; end if;
  if v_order.payment_method='Xendit' and v_order.payment_status<>'paid' then
    raise exception 'Wait for Xendit to confirm payment before processing this order.';
  end if;
  if v_order.payment_method='Xendit' and p_status='cancelled' then
    raise exception 'Online refunds are not enabled yet. Do not cancel a paid order in the app.';
  end if;
  if p_status='cancelled' then
    update public.products p set
      quantity=p.quantity+oi.quantity,
      status=case when p.status='sold_out' then 'available' else p.status end
    from public.order_items oi
    where oi.order_id=p_order_id and oi.product_id=p.id;
  end if;
  update public.orders set status=p_status where id=p_order_id;
end; $$;

create or replace function public.submit_order_review(
  p_order_id uuid,
  p_rating integer,
  p_comment text default ''
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_review_id uuid;
begin
  if p_rating not between 1 and 5 then raise exception 'Choose a rating from 1 to 5.'; end if;
  if char_length(trim(coalesce(p_comment,'')))>1000 or coalesce(p_comment,'')~'[<>]' then
    raise exception 'Enter a valid review of up to 1000 characters.';
  end if;
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.buyer_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status<>'completed' then raise exception 'Receive the order before reviewing it.'; end if;
  if exists(
    select 1 from public.order_returns
    where order_id=p_order_id and status not in ('rejected','cancelled','resolved')
  ) then raise exception 'Finish the return request before reviewing this order.'; end if;

  insert into public.order_reviews(order_id,buyer_id,seller_id,shop_id,rating,comment)
  values(p_order_id,v_order.buyer_id,v_order.seller_id,v_order.shop_id,p_rating,trim(coalesce(p_comment,'')))
  on conflict(order_id) do update set rating=excluded.rating,comment=excluded.comment
  returning id into v_review_id;
  return v_review_id;
end; $$;

create or replace function public.request_order_return(
  p_order_id uuid,
  p_reason text,
  p_details text
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_return_id uuid;
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
  if v_order.id is null or v_order.buyer_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status<>'completed' then raise exception 'Receive the order before requesting a return.'; end if;

  insert into public.order_returns(order_id,buyer_id,seller_id,shop_id,reason,details)
  values(p_order_id,v_order.buyer_id,v_order.seller_id,v_order.shop_id,p_reason,trim(p_details))
  on conflict(order_id) do update set
    reason=excluded.reason,details=excluded.details,status='requested'
  where public.order_returns.status in ('rejected','cancelled','resolved')
  returning id into v_return_id;
  if v_return_id is null then raise exception 'This order already has an active return request.'; end if;
  return v_return_id;
end; $$;

create or replace function public.cancel_order_return(p_return_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.order_returns set status='cancelled'
  where id=p_return_id and buyer_id=auth.uid() and status='requested';
  if not found then raise exception 'This return request can no longer be cancelled.'; end if;
end; $$;

create or replace function public.update_return_status(
  p_return_id uuid,
  p_status text
) returns void language plpgsql security definer set search_path=public as $$
declare v_return public.order_returns%rowtype;
begin
  if p_status not in ('approved','rejected','received','resolved') then
    raise exception 'Invalid return status.';
  end if;
  select * into v_return from public.order_returns where id=p_return_id for update;
  if v_return.id is null or v_return.seller_id<>auth.uid() then raise exception 'Return request not found.'; end if;
  if not (
    (v_return.status='requested' and p_status in ('approved','rejected')) or
    (v_return.status='approved' and p_status='received') or
    (v_return.status='received' and p_status='resolved')
  ) then raise exception 'That return status change is not allowed.'; end if;
  update public.order_returns set status=p_status where id=p_return_id;
end; $$;

revoke all on function public.mark_order_received(uuid) from public;
revoke all on function public.submit_order_review(uuid,integer,text) from public;
revoke all on function public.request_order_return(uuid,text,text) from public;
revoke all on function public.cancel_order_return(uuid) from public;
revoke all on function public.update_return_status(uuid,text) from public;
grant execute on function public.mark_order_received(uuid) to authenticated;
grant execute on function public.submit_order_review(uuid,integer,text) to authenticated;
grant execute on function public.request_order_return(uuid,text,text) to authenticated;
grant execute on function public.cancel_order_return(uuid) to authenticated;
grant execute on function public.update_return_status(uuid,text) to authenticated;

notify pgrst, 'reload schema';
