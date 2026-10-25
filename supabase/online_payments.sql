-- Tkoi Xendit online payments migration.
-- Safe for the existing database: no tables or accounts are deleted.

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'PHP' check (currency = 'PHP'),
  status text not null default 'creating'
    check (status in ('creating','pending','paid','expired','failed','cancelled')),
  payment_channel text,
  xendit_session_id text unique,
  xendit_payment_id text,
  checkout_url text,
  expires_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payment_transactions
  add column if not exists payment_channel text;
alter table public.payment_transactions
  drop constraint if exists payment_transactions_channel_check;
alter table public.payment_transactions
  add constraint payment_transactions_channel_check check (
    payment_channel is null or payment_channel in (
      'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
      'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH','ONLINE'
    )
  ) not valid;

create index if not exists payment_transactions_buyer_idx
  on public.payment_transactions(buyer_id, created_at desc);
create index if not exists payment_transactions_session_idx
  on public.payment_transactions(xendit_session_id);

drop trigger if exists payment_transactions_set_updated_at
  on public.payment_transactions;
create trigger payment_transactions_set_updated_at
before update on public.payment_transactions
for each row execute function public.set_updated_at();

alter table public.payment_transactions enable row level security;
drop policy if exists "Buyers view own payment transactions"
  on public.payment_transactions;
create policy "Buyers view own payment transactions"
on public.payment_transactions for select to authenticated
using (buyer_id=auth.uid());

alter table public.orders
  add column if not exists payment_transaction_id uuid
    references public.payment_transactions(id) on delete restrict,
  add column if not exists payment_status text not null default 'not_required',
  add column if not exists payment_channel text;

-- Preserve any pending orders created by the earlier generic online checkout.
alter table public.orders drop constraint if exists orders_payment_channel_check;
update public.orders set payment_channel='ONLINE'
where payment_method='Xendit' and payment_channel is null;
update public.payment_transactions t set payment_channel=coalesce(
  (select o.payment_channel from public.orders o
   where o.payment_transaction_id=t.id limit 1),
  'ONLINE'
)
where t.payment_channel is null;

alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check
  check (payment_method in ('Cash on Delivery','Xendit')) not valid;
alter table public.orders drop constraint if exists orders_payment_status_check;
alter table public.orders add constraint orders_payment_status_check
  check (payment_status in ('not_required','creating','pending','paid','expired','failed','cancelled')) not valid;
alter table public.orders drop constraint if exists orders_payment_consistency;
alter table public.orders add constraint orders_payment_consistency check (
  (payment_method='Cash on Delivery' and payment_status='not_required'
    and payment_transaction_id is null and payment_channel is null)
  or
  (payment_method='Xendit' and payment_status<>'not_required'
    and payment_transaction_id is not null and payment_channel is not null)
) not valid;
alter table public.orders drop constraint if exists orders_payment_channel_check;
alter table public.orders add constraint orders_payment_channel_check check (
  payment_channel is null or payment_channel in (
    'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
    'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH','ONLINE'
  )
) not valid;

create index if not exists orders_payment_transaction_idx
  on public.orders(payment_transaction_id);

drop function if exists public.prepare_xendit_cart(text);
drop function if exists public.prepare_xendit_cart(text,text);
create function public.prepare_xendit_cart(
  p_delivery_address text,
  p_payment_channel text
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_group record;
  v_transaction_id uuid;
  v_order_id uuid;
  v_order_ids uuid[]:='{}';
  v_total numeric(12,2);
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if char_length(trim(p_delivery_address)) not between 10 and 300
     or p_delivery_address~'[<>]' then
    raise exception 'Enter a valid delivery address.';
  end if;
  if p_payment_channel not in (
    'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
    'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH'
  ) then raise exception 'Choose a supported payment method.'; end if;
  if not exists(select 1 from cart_items where buyer_id=v_user) then
    raise exception 'Your cart is empty.';
  end if;

  perform p.id from products p
  join cart_items c on c.product_id=p.id
  where c.buyer_id=v_user order by p.id for update of p;

  if exists(
    select 1 from cart_items c join products p on p.id=c.product_id
    where c.buyer_id=v_user and (
      p.seller_id=v_user or p.status<>'available' or p.quantity<c.quantity
    )
  ) then
    raise exception 'A cart item is unavailable, belongs to you, or has insufficient stock.';
  end if;

  select sum(c.quantity*p.price)::numeric(12,2) into v_total
  from cart_items c join products p on p.id=c.product_id
  where c.buyer_id=v_user;

  insert into payment_transactions(
    buyer_id,amount,status,expires_at,payment_channel
  )
  values(
    v_user,v_total,'creating',now()+interval '30 minutes',p_payment_channel
  )
  returning id into v_transaction_id;

  for v_group in
    select p.shop_id,p.seller_id,sum(c.quantity*p.price)::numeric(12,2) total
    from cart_items c join products p on p.id=c.product_id
    where c.buyer_id=v_user group by p.shop_id,p.seller_id
  loop
    insert into orders(
      buyer_id,seller_id,shop_id,total,delivery_address,payment_method,
      payment_status,payment_transaction_id,payment_channel
    ) values(
      v_user,v_group.seller_id,v_group.shop_id,v_group.total,
      trim(p_delivery_address),'Xendit','creating',v_transaction_id,
      p_payment_channel
    ) returning id into v_order_id;

    insert into order_items(
      order_id,product_id,shop_id,seller_id,product_name,quantity,unit_price,image_url
    )
    select v_order_id,p.id,p.shop_id,p.seller_id,p.name,c.quantity,p.price,
      (select pi.image_url from product_images pi
       where pi.product_id=p.id order by pi.sort_order,pi.created_at limit 1)
    from cart_items c join products p on p.id=c.product_id
    where c.buyer_id=v_user and p.shop_id=v_group.shop_id;

    update products p set
      quantity=p.quantity-c.quantity,
      status=case when p.quantity-c.quantity=0 then 'sold_out' else p.status end
    from cart_items c
    where c.buyer_id=v_user and c.product_id=p.id
      and p.shop_id=v_group.shop_id;
    v_order_ids:=array_append(v_order_ids,v_order_id);
  end loop;

  delete from cart_items where buyer_id=v_user;
  return jsonb_build_object(
    'transaction_id',v_transaction_id,
    'amount',v_total,
    'order_ids',to_jsonb(v_order_ids)
  );
end; $$;

drop function if exists public.prepare_xendit_buy_now(uuid,integer,text);
drop function if exists public.prepare_xendit_buy_now(uuid,integer,text,text);
create function public.prepare_xendit_buy_now(
  p_product_id uuid,
  p_quantity integer,
  p_delivery_address text,
  p_payment_channel text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_product products%rowtype;
  v_transaction_id uuid;
  v_order_id uuid;
  v_total numeric(12,2);
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_quantity<1 or p_quantity>1000 then raise exception 'Invalid quantity.'; end if;
  if char_length(trim(p_delivery_address)) not between 10 and 300
     or p_delivery_address~'[<>]' then
    raise exception 'Enter a valid delivery address.';
  end if;
  if p_payment_channel not in (
    'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
    'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH'
  ) then raise exception 'Choose a supported payment method.'; end if;

  select * into v_product from products where id=p_product_id for update;
  if v_product.id is null then raise exception 'Fish listing not found.'; end if;
  if v_product.seller_id=v_user then raise exception 'You cannot buy your own listing.'; end if;
  if v_product.status<>'available' or v_product.quantity<p_quantity then
    raise exception 'The requested quantity is no longer available.';
  end if;
  v_total:=(v_product.price*p_quantity)::numeric(12,2);

  insert into payment_transactions(
    buyer_id,amount,status,expires_at,payment_channel
  )
  values(
    v_user,v_total,'creating',now()+interval '30 minutes',p_payment_channel
  )
  returning id into v_transaction_id;

  insert into orders(
    buyer_id,seller_id,shop_id,total,delivery_address,payment_method,
    payment_status,payment_transaction_id,payment_channel
  ) values(
    v_user,v_product.seller_id,v_product.shop_id,v_total,
    trim(p_delivery_address),'Xendit','creating',v_transaction_id,
    p_payment_channel
  ) returning id into v_order_id;

  insert into order_items(
    order_id,product_id,shop_id,seller_id,product_name,quantity,unit_price,image_url
  ) values(
    v_order_id,v_product.id,v_product.shop_id,v_product.seller_id,
    v_product.name,p_quantity,v_product.price,
    (select pi.image_url from product_images pi
     where pi.product_id=v_product.id order by pi.sort_order,pi.created_at limit 1)
  );

  update products set
    quantity=quantity-p_quantity,
    status=case when quantity-p_quantity=0 then 'sold_out' else status end
  where id=p_product_id;

  return jsonb_build_object(
    'transaction_id',v_transaction_id,
    'amount',v_total,
    'order_ids',jsonb_build_array(v_order_id)
  );
end; $$;

create or replace function public.set_xendit_session(
  p_transaction_id uuid,
  p_session_id text,
  p_checkout_url text,
  p_expires_at timestamptz
) returns void language plpgsql security definer set search_path=public as $$
begin
  update payment_transactions set
    status='pending',xendit_session_id=p_session_id,
    checkout_url=p_checkout_url,expires_at=p_expires_at
  where id=p_transaction_id and status='creating';
  if not found then raise exception 'Payment transaction is not available.'; end if;
  update orders set payment_status='pending'
  where payment_transaction_id=p_transaction_id and payment_status='creating';
end; $$;

create or replace function public.complete_xendit_payment(
  p_transaction_id uuid,
  p_session_id text,
  p_payment_id text,
  p_amount numeric,
  p_currency text
) returns void language plpgsql security definer set search_path=public as $$
declare v_transaction payment_transactions%rowtype;
begin
  select * into v_transaction from payment_transactions
  where id=p_transaction_id for update;
  if v_transaction.id is null then raise exception 'Payment transaction not found.'; end if;
  if v_transaction.status='paid' then return; end if;
  if v_transaction.status not in ('creating','pending') then
    raise exception 'Payment transaction is already closed.';
  end if;
  if v_transaction.xendit_session_id is distinct from p_session_id
     or v_transaction.amount<>p_amount or p_currency<>'PHP' then
    raise exception 'Payment verification failed.';
  end if;
  update payment_transactions set status='paid',xendit_payment_id=p_payment_id
  where id=p_transaction_id;
  update orders set payment_status='paid'
  where payment_transaction_id=p_transaction_id;
end; $$;

create or replace function public.fail_xendit_payment(
  p_transaction_id uuid,
  p_status text,
  p_reason text default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_transaction payment_transactions%rowtype;
begin
  if p_status not in ('expired','failed','cancelled') then
    raise exception 'Invalid failed payment status.';
  end if;
  select * into v_transaction from payment_transactions
  where id=p_transaction_id for update;
  if v_transaction.id is null then raise exception 'Payment transaction not found.'; end if;
  if v_transaction.status in ('expired','failed','cancelled') then return; end if;
  if v_transaction.status='paid' then raise exception 'A paid transaction cannot be cancelled.'; end if;

  update products p set
    quantity=p.quantity+restored.quantity,
    status=case when p.status='sold_out' then 'available' else p.status end
  from (
    select oi.product_id,sum(oi.quantity)::integer quantity
    from order_items oi join orders o on o.id=oi.order_id
    where o.payment_transaction_id=p_transaction_id and oi.product_id is not null
    group by oi.product_id
  ) restored
  where p.id=restored.product_id;

  update orders set status='cancelled',payment_status=p_status
  where payment_transaction_id=p_transaction_id and status='pending';
  update payment_transactions set status=p_status,failure_reason=left(p_reason,500)
  where id=p_transaction_id;
end; $$;

-- COD orders can still be cancelled normally. Online cancellations must first
-- cancel the Xendit Session through the authenticated Edge Function.
create or replace function public.cancel_order(p_order_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare v_order orders%rowtype;
begin
  select * into v_order from orders where id=p_order_id for update;
  if v_order.id is null or v_order.buyer_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status<>'pending' then raise exception 'Only pending orders can be cancelled.'; end if;
  if v_order.payment_method='Xendit' then
    raise exception 'Cancel this online payment from its Xendit payment controls.';
  end if;
  update products p set quantity=p.quantity+oi.quantity,
    status=case when p.status='sold_out' then 'available' else p.status end
    from order_items oi where oi.order_id=p_order_id and oi.product_id=p.id;
  update orders set status='cancelled' where id=p_order_id;
end; $$;

create or replace function public.update_order_status(p_order_id uuid,p_status text) returns void
language plpgsql security definer set search_path=public as $$
declare v_order orders%rowtype;
begin
  if p_status not in ('pending','confirmed','preparing','ready_for_delivery','shipped','completed','cancelled') then raise exception 'Invalid order status.'; end if;
  select * into v_order from orders where id=p_order_id for update;
  if v_order.id is null or v_order.seller_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status in ('completed','cancelled') then raise exception 'A completed or cancelled order cannot be changed.'; end if;
  if v_order.payment_method='Xendit' and v_order.payment_status<>'paid' then
    raise exception 'Wait for Xendit to confirm payment before processing this order.';
  end if;
  if v_order.payment_method='Xendit' and p_status='cancelled' then
    raise exception 'Online refunds are not enabled yet. Do not cancel a paid order in the app.';
  end if;
  if p_status='cancelled' then
    update products p set quantity=p.quantity+oi.quantity,
      status=case when p.status='sold_out' then 'available' else p.status end
      from order_items oi where oi.order_id=p_order_id and oi.product_id=p.id;
  end if;
  update orders set status=p_status where id=p_order_id;
end; $$;

revoke all on function public.prepare_xendit_cart(text,text) from public;
revoke all on function public.prepare_xendit_buy_now(uuid,integer,text,text) from public;
grant execute on function public.prepare_xendit_cart(text,text) to authenticated;
grant execute on function public.prepare_xendit_buy_now(uuid,integer,text,text) to authenticated;

revoke all on function public.set_xendit_session(uuid,text,text,timestamptz) from public;
revoke all on function public.complete_xendit_payment(uuid,text,text,numeric,text) from public;
revoke all on function public.fail_xendit_payment(uuid,text,text) from public;
grant execute on function public.set_xendit_session(uuid,text,text,timestamptz) to service_role;
grant execute on function public.complete_xendit_payment(uuid,text,text,numeric,text) to service_role;
grant execute on function public.fail_xendit_payment(uuid,text,text) to service_role;

notify pgrst, 'reload schema';
