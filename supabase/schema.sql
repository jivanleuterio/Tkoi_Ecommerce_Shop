-- Tkoi database setup
-- WARNING: resets the old Tkoi/Xendit demo tables. Back up needed rows first.
create extension if not exists pgcrypto;

drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.payment_transactions cascade;
drop table if exists public.cart_items cascade;
drop table if exists public.product_images cascade;
drop table if exists public.products cascade;
drop table if exists public.shops cascade;
drop table if exists public.profiles cascade;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '', username text not null unique,
  email text not null, mobile_number text not null default '',
  address text not null default '', avatar_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null, owner_name text not null, description text not null default '',
  contact_number text not null, email text not null, location text not null, logo_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  name text not null, species text not null,
  category text not null check (category in ('Koi','Goldfish','Betta','Guppy','Molly','Cichlid','Arowana','Catfish','Marine Fish','Other')),
  description text not null default '', price numeric(12,2) not null check (price > 0),
  quantity integer not null default 1 check (quantity >= 0), size text not null,
  age_months integer check (age_months is null or age_months >= 0),
  sex text not null default 'Unknown' check (sex in ('Male','Female','Unknown')),
  health_condition text not null, seller_location text not null,
  status text not null default 'available' check (status in ('available','sold_out','hidden')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null, sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (buyer_id, product_id)
);
create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'PHP' check (currency = 'PHP'),
  status text not null default 'creating'
    check (status in ('creating','pending','paid','expired','failed','cancelled')),
  payment_channel text check (payment_channel is null or payment_channel in (
    'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
    'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH','ONLINE'
  )),
  xendit_session_id text unique, xendit_payment_id text, checkout_url text,
  expires_at timestamptz, failure_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','confirmed','preparing','ready_for_delivery','shipped','completed','cancelled')),
  total numeric(12,2) not null check (total >= 0), delivery_address text not null,
  payment_method text not null default 'Cash on Delivery'
    check (payment_method in ('Cash on Delivery','Xendit')),
  payment_status text not null default 'not_required'
    check (payment_status in ('not_required','creating','pending','paid','expired','failed','cancelled')),
  payment_transaction_id uuid references public.payment_transactions(id) on delete restrict,
  payment_channel text check (payment_channel is null or payment_channel in (
    'GCASH','PAYMAYA','CARDS','BPI_ONLINE_BANKING',
    'BDO_ONLINE_BANKING','UNIONBANK_ONLINE_BANKING','QRPH','ONLINE'
  )),
  constraint orders_payment_consistency check (
    (payment_method='Cash on Delivery' and payment_status='not_required'
      and payment_transaction_id is null and payment_channel is null)
    or
    (payment_method='Xendit' and payment_status<>'not_required'
      and payment_transaction_id is not null and payment_channel is not null)
  ),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  shop_id uuid not null references public.shops(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  product_name text not null, quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price > 0), image_url text,
  created_at timestamptz not null default now()
);

create index products_created_at_idx on public.products(created_at desc);
create index products_category_idx on public.products(category);
create index products_shop_id_idx on public.products(shop_id);
create index products_seller_id_idx on public.products(seller_id);
create index cart_items_buyer_id_idx on public.cart_items(buyer_id);
create index payment_transactions_buyer_idx on public.payment_transactions(buyer_id,created_at desc);
create index payment_transactions_session_idx on public.payment_transactions(xendit_session_id);
create index orders_buyer_id_idx on public.orders(buyer_id);
create index orders_seller_id_idx on public.orders(seller_id);
create index orders_shop_id_idx on public.orders(shop_id);
create index orders_payment_transaction_idx on public.orders(payment_transaction_id);
create index order_items_order_id_idx on public.order_items(order_id);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger shops_set_updated_at before update on public.shops for each row execute function public.set_updated_at();
create trigger products_set_updated_at before update on public.products for each row execute function public.set_updated_at();
create trigger cart_items_set_updated_at before update on public.cart_items for each row execute function public.set_updated_at();
create trigger payment_transactions_set_updated_at before update on public.payment_transactions for each row execute function public.set_updated_at();
create trigger orders_set_updated_at before update on public.orders for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id,full_name,username,email,mobile_number,address)
  values(new.id, coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'New User'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'username'),''), split_part(new.email,'@',1)||'_'||left(new.id::text,6)),
    coalesce(new.email,''), coalesce(nullif(trim(new.raw_user_meta_data->>'mobile_number'),''),'09100000000'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'address'),''),'Address not provided'));
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.cart_items enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create or replace function public.is_phone_verified(target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists(select 1 from auth.users u where u.id=target_user and u.phone is not null and u.phone_confirmed_at is not null);
$$;
revoke all on function public.is_phone_verified(uuid) from public;
grant execute on function public.is_phone_verified(uuid) to authenticated;

create or replace function public.is_product_in_my_cart(target_product uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.cart_items c where c.product_id=target_product and c.buyer_id=auth.uid());
$$;
revoke all on function public.is_product_in_my_cart(uuid) from public;
grant execute on function public.is_product_in_my_cart(uuid) to anon, authenticated;

create policy "Users view own profile" on public.profiles for select using (id=auth.uid());
create policy "Users update own profile" on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());
create policy "Anyone views shops" on public.shops for select using (true);
create policy "Owners create their shop" on public.shops for insert to authenticated with check (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Owners update their shop" on public.shops for update to authenticated using (owner_id=auth.uid() and public.is_phone_verified(auth.uid())) with check (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Owners delete their shop" on public.shops for delete to authenticated using (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Public views active products and sellers view own" on public.products
  for select using (
    (status='available' and quantity>0)
    or seller_id=auth.uid()
    or public.is_product_in_my_cart(id)
  );
create policy "Sellers create own products" on public.products for insert to authenticated
  with check (seller_id=auth.uid() and public.is_phone_verified(auth.uid()) and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid()));
create policy "Sellers update own products" on public.products for update to authenticated
  using (seller_id=auth.uid() and public.is_phone_verified(auth.uid())) with check (seller_id=auth.uid() and public.is_phone_verified(auth.uid()) and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid()));
create policy "Sellers delete own products" on public.products for delete to authenticated using (seller_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Users view images for visible products" on public.product_images for select using
  (exists(select 1 from public.products p where p.id=product_id and ((p.status='available' and p.quantity>0) or p.seller_id=auth.uid())));
create policy "Sellers add own product images" on public.product_images for insert to authenticated with check
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
create policy "Sellers update own product images" on public.product_images for update to authenticated using
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
create policy "Sellers delete own product images" on public.product_images for delete to authenticated using
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
create policy "Buyers view own cart" on public.cart_items for select to authenticated using (buyer_id=auth.uid());
create policy "Buyers add to own cart" on public.cart_items for insert to authenticated with check
  (buyer_id=auth.uid() and exists(select 1 from public.products p where p.id=product_id and p.seller_id<>auth.uid()));
create policy "Buyers update own cart" on public.cart_items for update to authenticated using (buyer_id=auth.uid()) with check (buyer_id=auth.uid());
create policy "Buyers delete own cart" on public.cart_items for delete to authenticated using (buyer_id=auth.uid());
create policy "Buyers view own payment transactions" on public.payment_transactions
  for select to authenticated using (buyer_id=auth.uid());
create policy "Buyers and sellers view related orders" on public.orders for select to authenticated
  using (buyer_id=auth.uid() or seller_id=auth.uid());
create policy "Buyers and sellers view related order items" on public.order_items for select to authenticated
  using (seller_id=auth.uid() or exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=auth.uid()));

-- Atomic checkout: lock/recheck stock, split by shop, reduce stock, clear cart.
create or replace function public.place_order(p_delivery_address text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_group record; v_order_id uuid; v_ids uuid[]:='{}';
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if nullif(trim(p_delivery_address),'') is null then raise exception 'Delivery address is required.'; end if;
  if not exists(select 1 from cart_items where buyer_id=v_user) then raise exception 'Your cart is empty.'; end if;
  perform p.id from products p join cart_items c on c.product_id=p.id
    where c.buyer_id=v_user order by p.id for update of p;
  if exists(select 1 from cart_items c join products p on p.id=c.product_id where c.buyer_id=v_user
    and (p.seller_id=v_user or p.status<>'available' or p.quantity<c.quantity)) then
    raise exception 'A cart item is unavailable, belongs to you, or has insufficient stock.';
  end if;
  for v_group in select p.shop_id,p.seller_id,sum(c.quantity*p.price)::numeric(12,2) total
    from cart_items c join products p on p.id=c.product_id where c.buyer_id=v_user group by p.shop_id,p.seller_id
  loop
    insert into orders(buyer_id,seller_id,shop_id,total,delivery_address,payment_method)
      values(v_user,v_group.seller_id,v_group.shop_id,v_group.total,trim(p_delivery_address),'Cash on Delivery') returning id into v_order_id;
    insert into order_items(order_id,product_id,shop_id,seller_id,product_name,quantity,unit_price,image_url)
      select v_order_id,p.id,p.shop_id,p.seller_id,p.name,c.quantity,p.price,
        (select pi.image_url from product_images pi where pi.product_id=p.id order by pi.sort_order,pi.created_at limit 1)
      from cart_items c join products p on p.id=c.product_id where c.buyer_id=v_user and p.shop_id=v_group.shop_id;
    update products p set quantity=p.quantity-c.quantity,
      status=case when p.quantity-c.quantity=0 then 'sold_out' else p.status end
      from cart_items c where c.buyer_id=v_user and c.product_id=p.id and p.shop_id=v_group.shop_id;
    v_ids:=array_append(v_ids,v_order_id);
  end loop;
  delete from cart_items where buyer_id=v_user;
  return jsonb_build_object('order_ids',to_jsonb(v_ids));
end; $$;

create or replace function public.add_to_cart(p_product_id uuid,p_quantity integer default 1)
returns void language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_product products%rowtype; v_existing integer:=0;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_quantity<1 or p_quantity>1000 then raise exception 'Invalid quantity.'; end if;
  select * into v_product from products where id=p_product_id for update;
  if v_product.id is null then raise exception 'Fish listing not found.'; end if;
  if v_product.seller_id=v_user then raise exception 'You cannot buy your own listing.'; end if;
  if v_product.status<>'available' or v_product.quantity<1 then raise exception 'This fish is not available.'; end if;
  select coalesce((select c.quantity from cart_items c where c.buyer_id=v_user and c.product_id=p_product_id),0) into v_existing;
  if v_existing+p_quantity>v_product.quantity then raise exception 'Only % item(s) are available.',v_product.quantity; end if;
  insert into cart_items(buyer_id,product_id,quantity) values(v_user,p_product_id,p_quantity)
  on conflict(buyer_id,product_id) do update set quantity=cart_items.quantity+excluded.quantity,updated_at=now();
end; $$;

create or replace function public.buy_now(p_product_id uuid,p_quantity integer,p_delivery_address text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_product products%rowtype; v_order_id uuid;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_quantity<1 or p_quantity>1000 then raise exception 'Invalid quantity.'; end if;
  if char_length(trim(p_delivery_address)) not between 10 and 300 or p_delivery_address~'[<>]' then raise exception 'Enter a valid delivery address.'; end if;
  select * into v_product from products where id=p_product_id for update;
  if v_product.id is null then raise exception 'Fish listing not found.'; end if;
  if v_product.seller_id=v_user then raise exception 'You cannot buy your own listing.'; end if;
  if v_product.status<>'available' or v_product.quantity<p_quantity then raise exception 'The requested quantity is no longer available.'; end if;
  insert into orders(buyer_id,seller_id,shop_id,total,delivery_address,payment_method)
    values(v_user,v_product.seller_id,v_product.shop_id,v_product.price*p_quantity,trim(p_delivery_address),'Cash on Delivery') returning id into v_order_id;
  insert into order_items(order_id,product_id,shop_id,seller_id,product_name,quantity,unit_price,image_url)
    values(v_order_id,v_product.id,v_product.shop_id,v_product.seller_id,v_product.name,p_quantity,v_product.price,
      (select pi.image_url from product_images pi where pi.product_id=v_product.id order by pi.sort_order,pi.created_at limit 1));
  update products set quantity=quantity-p_quantity,status=case when quantity-p_quantity=0 then 'sold_out' else status end where id=p_product_id;
  return v_order_id;
end; $$;

create or replace function public.cancel_order(p_order_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare v_order orders%rowtype;
begin
  select * into v_order from orders where id=p_order_id for update;
  if v_order.id is null or v_order.buyer_id<>auth.uid() then raise exception 'Order not found.'; end if;
  if v_order.status<>'pending' then raise exception 'Only pending orders can be cancelled.'; end if;
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
  if p_status='cancelled' then
    update products p set quantity=p.quantity+oi.quantity,
      status=case when p.status='sold_out' then 'available' else p.status end
      from order_items oi where oi.order_id=p_order_id and oi.product_id=p.id;
  end if;
  update orders set status=p_status where id=p_order_id;
end; $$;

revoke all on function public.place_order(text) from public;
revoke all on function public.add_to_cart(uuid,integer) from public;
revoke all on function public.buy_now(uuid,integer,text) from public;
revoke all on function public.cancel_order(uuid) from public;
revoke all on function public.update_order_status(uuid,text) from public;
grant execute on function public.place_order(text) to authenticated;
grant execute on function public.add_to_cart(uuid,integer) to authenticated;
grant execute on function public.buy_now(uuid,integer,text) to authenticated;

notify pgrst, 'reload schema';
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.update_order_status(uuid,text) to authenticated;

insert into storage.buckets(id,name,public) values
 ('profile-pictures','profile-pictures',true),('shop-logos','shop-logos',true),('product-images','product-images',true)
on conflict(id) do update set public=excluded.public;
drop policy if exists "Public reads Tkoi images" on storage.objects;
drop policy if exists "Users upload Tkoi images" on storage.objects;
drop policy if exists "Users update own Tkoi images" on storage.objects;
drop policy if exists "Users delete own Tkoi images" on storage.objects;
drop policy if exists "Users upload profile pictures" on storage.objects;
drop policy if exists "Users update profile pictures" on storage.objects;
drop policy if exists "Users delete profile pictures" on storage.objects;
drop policy if exists "Verified sellers upload images" on storage.objects;
drop policy if exists "Verified sellers update images" on storage.objects;
drop policy if exists "Verified sellers delete images" on storage.objects;
create policy "Public reads Tkoi images" on storage.objects for select
  using (bucket_id in ('profile-pictures','shop-logos','product-images'));
create policy "Users upload profile pictures" on storage.objects for insert to authenticated with check
  (bucket_id='profile-pictures' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "Users update profile pictures" on storage.objects for update to authenticated using
  (bucket_id='profile-pictures' and owner_id=auth.uid()::text);
create policy "Users delete profile pictures" on storage.objects for delete to authenticated using
  (bucket_id='profile-pictures' and owner_id=auth.uid()::text);
create policy "Verified sellers upload images" on storage.objects for insert to authenticated with check
  (bucket_id in ('shop-logos','product-images') and (storage.foldername(name))[1]=auth.uid()::text and public.is_phone_verified(auth.uid()));
create policy "Verified sellers update images" on storage.objects for update to authenticated using
  (bucket_id in ('shop-logos','product-images') and owner_id=auth.uid()::text and public.is_phone_verified(auth.uid()));
create policy "Verified sellers delete images" on storage.objects for delete to authenticated using
  (bucket_id in ('shop-logos','product-images') and owner_id=auth.uid()::text and public.is_phone_verified(auth.uid()));

-- Backfill profiles for Auth users created before this trigger existed.
insert into public.profiles(id,full_name,username,email,mobile_number,address)
select u.id,coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'),''),'New User'),
  coalesce(nullif(trim(u.raw_user_meta_data->>'username'),''),split_part(u.email,'@',1)||'_'||left(u.id::text,6)),
  coalesce(u.email,''),coalesce(nullif(trim(u.raw_user_meta_data->>'mobile_number'),''),'09100000000'),coalesce(nullif(trim(u.raw_user_meta_data->>'address'),''),'Address not provided')
from auth.users u on conflict(id) do nothing;
