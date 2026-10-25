-- Run this once in Supabase SQL Editor after schema.sql.
-- It adds server-side validation to databases that were already set up.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id,full_name,username,email,mobile_number,address)
  values(
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'New User'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'username'),''),split_part(new.email,'@',1)||'_'||left(new.id::text,6)),
    coalesce(new.email,''),
    coalesce(nullif(trim(new.raw_user_meta_data->>'mobile_number'),''),'09100000000'),
    coalesce(nullif(trim(new.raw_user_meta_data->>'address'),''),'Address not provided')
  );
  return new;
end; $$;

create or replace function public.is_phone_verified(target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists(
    select 1 from auth.users u
    where u.id = target_user
      and u.phone is not null
      and u.phone_confirmed_at is not null
  );
$$;
revoke all on function public.is_phone_verified(uuid) from public;
grant execute on function public.is_phone_verified(uuid) to authenticated;

create or replace function public.is_product_in_my_cart(target_product uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.cart_items c where c.product_id=target_product and c.buyer_id=auth.uid());
$$;
revoke all on function public.is_product_in_my_cart(uuid) from public;
grant execute on function public.is_product_in_my_cart(uuid) to anon, authenticated;

drop policy if exists "Public views active products and sellers view own" on public.products;
create policy "Public views active products and sellers view own" on public.products
for select using (
  (status='available' and quantity>0)
  or seller_id=auth.uid()
  or public.is_product_in_my_cart(id)
);

-- Recreate seller policies with server-side verified-phone enforcement.
drop policy if exists "Owners create their shop" on public.shops;
drop policy if exists "Owners update their shop" on public.shops;
drop policy if exists "Owners delete their shop" on public.shops;
create policy "Owners create their shop" on public.shops for insert to authenticated
  with check (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Owners update their shop" on public.shops for update to authenticated
  using (owner_id=auth.uid() and public.is_phone_verified(auth.uid()))
  with check (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));
create policy "Owners delete their shop" on public.shops for delete to authenticated
  using (owner_id=auth.uid() and public.is_phone_verified(auth.uid()));

drop policy if exists "Sellers create own products" on public.products;
drop policy if exists "Sellers update own products" on public.products;
drop policy if exists "Sellers delete own products" on public.products;
create policy "Sellers create own products" on public.products for insert to authenticated
  with check (
    seller_id=auth.uid() and public.is_phone_verified(auth.uid())
    and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
  );
create policy "Sellers update own products" on public.products for update to authenticated
  using (seller_id=auth.uid() and public.is_phone_verified(auth.uid()))
  with check (
    seller_id=auth.uid() and public.is_phone_verified(auth.uid())
    and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=auth.uid())
  );
create policy "Sellers delete own products" on public.products for delete to authenticated
  using (seller_id=auth.uid() and public.is_phone_verified(auth.uid()));

drop policy if exists "Sellers add own product images" on public.product_images;
drop policy if exists "Sellers update own product images" on public.product_images;
drop policy if exists "Sellers delete own product images" on public.product_images;
create policy "Sellers add own product images" on public.product_images for insert to authenticated with check
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
create policy "Sellers update own product images" on public.product_images for update to authenticated using
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
create policy "Sellers delete own product images" on public.product_images for delete to authenticated using
  (public.is_phone_verified(auth.uid()) and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));

-- Prevent unverified accounts from filling seller-image storage directly.
drop policy if exists "Users upload Tkoi images" on storage.objects;
drop policy if exists "Users update own Tkoi images" on storage.objects;
drop policy if exists "Users delete own Tkoi images" on storage.objects;
drop policy if exists "Users upload profile pictures" on storage.objects;
drop policy if exists "Users update profile pictures" on storage.objects;
drop policy if exists "Users delete profile pictures" on storage.objects;
drop policy if exists "Verified sellers upload images" on storage.objects;
drop policy if exists "Verified sellers update images" on storage.objects;
drop policy if exists "Verified sellers delete images" on storage.objects;
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

-- NOT VALID avoids failing because of older demo rows, while still enforcing
-- each constraint on all new inserts and updates.
alter table public.profiles drop constraint if exists profiles_full_name_quality;
alter table public.profiles add constraint profiles_full_name_quality
  check (char_length(trim(full_name)) between 2 and 80 and full_name !~ '[<>]') not valid;
alter table public.profiles drop constraint if exists profiles_username_quality;
alter table public.profiles add constraint profiles_username_quality
  check (username ~ '^[A-Za-z0-9_]{3,30}$') not valid;
alter table public.profiles drop constraint if exists profiles_email_quality;
alter table public.profiles add constraint profiles_email_quality
  check (char_length(email) between 5 and 254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') not valid;
alter table public.profiles drop constraint if exists profiles_mobile_quality;
alter table public.profiles add constraint profiles_mobile_quality
  check (mobile_number ~ '^(\+639|09)[0-9]{9}$') not valid;
alter table public.profiles drop constraint if exists profiles_address_quality;
alter table public.profiles add constraint profiles_address_quality
  check (char_length(trim(address)) between 10 and 300 and address !~ '[<>]') not valid;

alter table public.shops drop constraint if exists shops_name_quality;
alter table public.shops add constraint shops_name_quality
  check (char_length(trim(name)) between 3 and 80 and name !~ '[<>]') not valid;
alter table public.shops drop constraint if exists shops_owner_name_quality;
alter table public.shops add constraint shops_owner_name_quality
  check (char_length(trim(owner_name)) between 2 and 80 and owner_name !~ '[<>]') not valid;
alter table public.shops drop constraint if exists shops_description_quality;
alter table public.shops add constraint shops_description_quality
  check (char_length(trim(description)) between 20 and 1000 and description !~ '[<>]') not valid;
alter table public.shops drop constraint if exists shops_contact_quality;
alter table public.shops add constraint shops_contact_quality
  check (contact_number ~ '^(\+639|09)[0-9]{9}$') not valid;
alter table public.shops drop constraint if exists shops_email_quality;
alter table public.shops add constraint shops_email_quality
  check (char_length(email) between 5 and 254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') not valid;
alter table public.shops drop constraint if exists shops_location_quality;
alter table public.shops add constraint shops_location_quality
  check (char_length(trim(location)) between 5 and 200 and location !~ '[<>]') not valid;

alter table public.products drop constraint if exists products_name_quality;
alter table public.products add constraint products_name_quality
  check (char_length(trim(name)) between 2 and 100 and name !~ '[<>]') not valid;
alter table public.products drop constraint if exists products_species_quality;
alter table public.products add constraint products_species_quality
  check (char_length(trim(species)) between 2 and 100 and species !~ '[<>]') not valid;
alter table public.products drop constraint if exists products_description_quality;
alter table public.products add constraint products_description_quality
  check (char_length(trim(description)) between 20 and 2000 and description !~ '[<>]') not valid;
alter table public.products drop constraint if exists products_price_limit;
alter table public.products add constraint products_price_limit
  check (price between 1 and 1000000) not valid;
alter table public.products drop constraint if exists products_quantity_limit;
alter table public.products add constraint products_quantity_limit
  check (quantity between 0 and 10000) not valid;
alter table public.products drop constraint if exists products_size_quality;
alter table public.products add constraint products_size_quality
  check (char_length(trim(size)) between 2 and 50 and size !~ '[<>]') not valid;
alter table public.products drop constraint if exists products_age_limit;
alter table public.products add constraint products_age_limit
  check (age_months is null or age_months between 0 and 1200) not valid;
alter table public.products drop constraint if exists products_health_quality;
alter table public.products add constraint products_health_quality
  check (char_length(trim(health_condition)) between 5 and 300 and health_condition !~ '[<>]') not valid;
alter table public.products drop constraint if exists products_location_quality;
alter table public.products add constraint products_location_quality
  check (char_length(trim(seller_location)) between 5 and 200 and seller_location !~ '[<>]') not valid;

alter table public.cart_items drop constraint if exists cart_quantity_limit;
alter table public.cart_items add constraint cart_quantity_limit
  check (quantity between 1 and 1000) not valid;
alter table public.orders drop constraint if exists orders_address_quality;
alter table public.orders add constraint orders_address_quality
  check (char_length(trim(delivery_address)) between 10 and 300 and delivery_address !~ '[<>]') not valid;

create or replace function public.enforce_order_status_transition()
returns trigger language plpgsql as $$
begin
  if new.status = old.status then return new; end if;
  if not (
    (old.status='pending' and new.status in ('confirmed','cancelled')) or
    (old.status='confirmed' and new.status in ('preparing','cancelled')) or
    (old.status='preparing' and new.status in ('ready_for_delivery','cancelled')) or
    (old.status='ready_for_delivery' and new.status in ('shipped','cancelled')) or
    (old.status='shipped' and new.status='completed')
  ) then
    raise exception 'Invalid order status change from % to %.', old.status, new.status;
  end if;
  return new;
end; $$;
drop trigger if exists orders_enforce_status_transition on public.orders;
create trigger orders_enforce_status_transition before update of status on public.orders
for each row execute function public.enforce_order_status_transition();
