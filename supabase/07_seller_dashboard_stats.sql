-- Batched seller dashboard and safe seller-order queries.
-- Additive and safe to rerun. Never exposes buyer email, phone, or profile address.

create or replace function public.get_seller_orders_secure(p_shop_id uuid)
returns table(
  id uuid,buyer_id uuid,seller_id uuid,shop_id uuid,status text,total numeric,
  delivery_address text,payment_method text,payment_status text,
  payment_channel text,payment_transaction_id uuid,created_at timestamptz,
  shop_name text,buyer_name text,buyer_avatar_url text,
  platform_fee numeric,net_earnings numeric,order_items jsonb
) language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query
  select o.id,o.buyer_id,o.seller_id,o.shop_id,o.status,o.total,
    o.delivery_address,o.payment_method,o.payment_status,o.payment_channel,
    o.payment_transaction_id,o.created_at,s.name,
    coalesce(nullif(trim(p.full_name),''),'Tkoi buyer'),p.avatar_url,
    case when o.payment_method='Xendit' then coalesce(abs(fee.amount),
      round(o.total*settings.platform_fee_percent/100,2)) else 0 end,
    case when o.payment_method='Xendit' then o.total-coalesce(abs(fee.amount),
      round(o.total*settings.platform_fee_percent/100,2)) else o.total end,
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',oi.id,'product_id',oi.product_id,'product_name',oi.product_name,
      'quantity',oi.quantity,'unit_price',oi.unit_price,'image_url',oi.image_url
    ) order by oi.created_at) from public.order_items oi where oi.order_id=o.id),'[]'::jsonb)
  from public.orders o
  join public.shops s on s.id=o.shop_id
  join public.profiles p on p.id=o.buyer_id
  cross join public.marketplace_settings settings
  left join public.seller_wallet_transactions fee
    on fee.order_id=o.id and fee.type='platform_fee'
  where o.shop_id=p_shop_id and settings.singleton=true
  order by o.created_at desc;
end; $$;

create or replace function public.get_seller_dashboard_stats(
  p_shop_id uuid,p_days integer default 7
) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_days integer;
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=v_user) then
    raise exception 'Shop not found.';
  end if;
  v_days:=case when p_days=30 then 30 else 7 end;
  return jsonb_build_object(
    'total_products',(select count(*) from public.products p where p.shop_id=p_shop_id),
    'available_products',(select count(*) from public.products p
      where p.shop_id=p_shop_id and p.status='available' and p.quantity>0),
    'pending_orders',(select count(*) from public.orders o
      where o.shop_id=p_shop_id and o.status='pending'),
    'completed_orders',(select count(*) from public.orders o
      where o.shop_id=p_shop_id and o.status='completed'),
    'total_revenue',(select coalesce(sum(o.total),0) from public.orders o
      where o.shop_id=p_shop_id and o.status='completed'),
    'to_ship',(select count(*) from public.orders o where o.shop_id=p_shop_id
      and o.status in ('confirmed','preparing','ready_for_delivery')),
    'active_returns',(select count(*) from public.orders o
      where o.shop_id=p_shop_id and public.order_return_has_any_status(
        o.id,array['requested','approved','received']::text[]
      )),
    'unread_chats',(select count(distinct c.id) from public.messages m
      join public.conversations c on c.id=m.conversation_id
      where (c.buyer_id=v_user or c.seller_id=v_user)
        and m.sender_id<>v_user and m.read_at is null),
    'low_stock',(select count(*) from public.products p where p.shop_id=p_shop_id
      and p.status<>'hidden' and p.quantity<=3),
    'average_rating',(select coalesce(round(avg(r.rating)::numeric,2),0)
      from public.product_reviews r where r.shop_id=p_shop_id),
    'total_reviews',(select count(*) from public.product_reviews r
      where r.shop_id=p_shop_id),
    'sales_points',coalesce((
      select jsonb_agg(jsonb_build_object(
        'day',days.day,'revenue',coalesce(sales.revenue,0),
        'orders',coalesce(sales.orders,0)
      ) order by days.day)
      from generate_series(current_date-(v_days-1),current_date,'1 day') days(day)
      left join lateral (
        select sum(o.total) revenue,count(*) orders from public.orders o
        where o.shop_id=p_shop_id and o.status='completed'
          and coalesce(o.completed_at,o.updated_at)::date=days.day::date
      ) sales on true
    ),'[]'::jsonb),
    'top_products',coalesce((
      select jsonb_agg(row_data order by sold_count desc) from (
        select jsonb_build_object(
          'product_id',p.id,'name',p.name,'sold_count',
          coalesce(sum(oi.quantity) filter(where o.id is not null),0),
          'image_url',(select pi.image_url from public.product_images pi
            where pi.product_id=p.id order by pi.sort_order,pi.created_at limit 1)
        ) row_data,coalesce(sum(oi.quantity) filter(where o.id is not null),0) sold_count
        from public.products p
        left join public.order_items oi on oi.product_id=p.id
        left join public.orders o on o.id=oi.order_id and o.status='completed'
        where p.shop_id=p_shop_id
        group by p.id,p.name order by sold_count desc limit 5
      ) ranked
    ),'[]'::jsonb),
    'recent_reviews',coalesce((
      select jsonb_agg(row_data order by created_at desc) from (
        select jsonb_build_object(
          'review_id',r.id,'product_id',r.product_id,'product_name',p.name,
          'buyer_name',coalesce(nullif(trim(profile.full_name),''),'Tkoi buyer'),
          'rating',r.rating,'comment',r.comment,'created_at',r.created_at
        ) row_data,r.created_at
        from public.product_reviews r
        join public.products p on p.id=r.product_id
        join public.profiles profile on profile.id=r.buyer_id
        where r.shop_id=p_shop_id order by r.created_at desc limit 5
      ) reviews
    ),'[]'::jsonb)
  );
end; $$;

revoke all on function public.get_seller_orders_secure(uuid) from public;
revoke all on function public.get_seller_dashboard_stats(uuid,integer) from public;
grant execute on function public.get_seller_orders_secure(uuid) to authenticated;
grant execute on function public.get_seller_dashboard_stats(uuid,integer) to authenticated;

notify pgrst,'reload schema';
