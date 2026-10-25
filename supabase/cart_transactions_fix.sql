-- Run this once in Supabase SQL Editor.
-- Fixes circular cart RLS and adds atomic Add to Cart / Buy Now functions.

create or replace function public.is_product_in_my_cart(target_product uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.cart_items c
    where c.product_id=target_product and c.buyer_id=auth.uid()
  );
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

create or replace function public.add_to_cart(
  p_product_id uuid,
  p_quantity integer default 1
) returns void language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_product products%rowtype;
  v_existing integer:=0;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_quantity < 1 or p_quantity > 1000 then raise exception 'Invalid quantity.'; end if;

  select * into v_product from products where id=p_product_id for update;
  if v_product.id is null then raise exception 'Fish listing not found.'; end if;
  if v_product.seller_id=v_user then raise exception 'You cannot buy your own listing.'; end if;
  if v_product.status<>'available' or v_product.quantity<1 then raise exception 'This fish is not available.'; end if;

  select coalesce((
    select c.quantity from cart_items c
    where c.buyer_id=v_user and c.product_id=p_product_id
  ),0) into v_existing;
  if v_existing+p_quantity>v_product.quantity then
    raise exception 'Only % item(s) are available.',v_product.quantity;
  end if;

  insert into cart_items(buyer_id,product_id,quantity)
  values(v_user,p_product_id,p_quantity)
  on conflict(buyer_id,product_id) do update
  set quantity=cart_items.quantity+excluded.quantity,updated_at=now();
end; $$;

create or replace function public.buy_now(
  p_product_id uuid,
  p_quantity integer,
  p_delivery_address text
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_product products%rowtype;
  v_order_id uuid;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_quantity<1 or p_quantity>1000 then raise exception 'Invalid quantity.'; end if;
  if char_length(trim(p_delivery_address)) not between 10 and 300 or p_delivery_address~'[<>]' then
    raise exception 'Enter a valid delivery address.';
  end if;

  select * into v_product from products where id=p_product_id for update;
  if v_product.id is null then raise exception 'Fish listing not found.'; end if;
  if v_product.seller_id=v_user then raise exception 'You cannot buy your own listing.'; end if;
  if v_product.status<>'available' or v_product.quantity<p_quantity then
    raise exception 'The requested quantity is no longer available.';
  end if;

  insert into orders(buyer_id,seller_id,shop_id,total,delivery_address,payment_method)
  values(v_user,v_product.seller_id,v_product.shop_id,v_product.price*p_quantity,trim(p_delivery_address),'Cash on Delivery')
  returning id into v_order_id;

  insert into order_items(order_id,product_id,shop_id,seller_id,product_name,quantity,unit_price,image_url)
  values(
    v_order_id,v_product.id,v_product.shop_id,v_product.seller_id,v_product.name,
    p_quantity,v_product.price,
    (select pi.image_url from product_images pi where pi.product_id=v_product.id order by pi.sort_order,pi.created_at limit 1)
  );

  update products
  set quantity=quantity-p_quantity,
      status=case when quantity-p_quantity=0 then 'sold_out' else status end
  where id=p_product_id;

  return v_order_id;
end; $$;

revoke all on function public.add_to_cart(uuid,integer) from public;
revoke all on function public.buy_now(uuid,integer,text) from public;
grant execute on function public.add_to_cart(uuid,integer) to authenticated;
grant execute on function public.buy_now(uuid,integer,text) to authenticated;

-- Make the new RPC functions available to the Flutter app immediately.
notify pgrst, 'reload schema';
