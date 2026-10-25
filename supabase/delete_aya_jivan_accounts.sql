-- One-time cleanup for the two named Tkoi test accounts.
-- Run this entire file by itself in the Supabase SQL Editor.
--
-- It matches Auth users by the two exact, case-insensitive email addresses,
-- removes their dependent marketplace data, then deletes their Auth users.
-- The whole operation is transactional: any unexpected foreign-key failure
-- rolls everything back.
--
-- Uploaded files are intentionally not deleted directly from storage.objects.
-- Supabase recommends deleting physical Storage objects through the Storage API
-- or dashboard. Remove folders named with the deleted user UUIDs separately if
-- their uploaded files also need to be physically removed.

begin;

do $$
declare
  v_account_ids uuid[] := '{}'::uuid[];
  v_order_ids uuid[] := '{}'::uuid[];
  v_payment_ids uuid[] := '{}'::uuid[];
  v_account_count integer := 0;
  v_deleted_count integer := 0;
begin
  select coalesce(array_agg(u.id), '{}'::uuid[])
  into v_account_ids
  from auth.users u
  where lower(u.email) in (
    'antoniorussel008@gmail.com',
    'jivan23leuterio@gmail.com'
  );

  v_account_count := cardinality(v_account_ids);

  if v_account_count = 0 then
    raise notice 'Neither requested account exists. Nothing was deleted.';
    return;
  end if;

  raise notice 'Found % matching account(s).', v_account_count;

  -- Capture affected orders before deleting dependent records.
  select coalesce(array_agg(affected.id), '{}'::uuid[])
  into v_order_ids
  from (
    select distinct o.id
    from public.orders o
    where o.buyer_id = any(v_account_ids)
       or o.seller_id = any(v_account_ids)
       or o.shop_id in (
         select s.id
         from public.shops s
         where s.owner_id = any(v_account_ids)
       )
  ) affected;

  select coalesce(array_agg(affected.id), '{}'::uuid[])
  into v_payment_ids
  from (
    select distinct o.payment_transaction_id as id
    from public.orders o
    where o.id = any(v_order_ids)
      and o.payment_transaction_id is not null
    union
    select pt.id
    from public.payment_transactions pt
    where pt.buyer_id = any(v_account_ids)
  ) affected;

  -- Removing an unfinished buyer order is equivalent to cancelling it, so
  -- return reserved stock when the product belongs to an account being kept.
  update public.products p
  set
    quantity = p.quantity + restored.quantity,
    status = case when p.status = 'sold_out' then 'available' else p.status end
  from (
    select oi.product_id, sum(oi.quantity)::integer as quantity
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where o.id = any(v_order_ids)
      and o.buyer_id = any(v_account_ids)
      and not (o.seller_id = any(v_account_ids))
      and o.status not in ('completed', 'cancelled')
      and oi.product_id is not null
    group by oi.product_id
  ) restored
  where p.id = restored.product_id;

  -- New feature tables may not have been installed yet, so clean them only
  -- when they exist. Positional parameters keep UUID values out of SQL text.
  if to_regclass('public.messages') is not null then
    execute
      'delete from public.messages where sender_id = any($1)'
      using v_account_ids;
  end if;

  if to_regclass('public.conversations') is not null then
    execute
      'delete from public.conversations '
      'where buyer_id = any($1) or seller_id = any($1)'
      using v_account_ids;
  end if;

  if to_regclass('public.product_reviews') is not null then
    execute
      'delete from public.product_reviews '
      'where buyer_id = any($1) or seller_id = any($1) '
      'or order_id = any($2)'
      using v_account_ids, v_order_ids;
  end if;

  if to_regclass('public.order_reviews') is not null then
    execute
      'delete from public.order_reviews '
      'where buyer_id = any($1) or seller_id = any($1) '
      'or order_id = any($2)'
      using v_account_ids, v_order_ids;
  end if;

  if to_regclass('public.order_returns') is not null then
    execute
      'delete from public.order_returns '
      'where buyer_id = any($1) or seller_id = any($1) '
      'or order_id = any($2)'
      using v_account_ids, v_order_ids;
  end if;

  -- order_items and their product reviews/images cascade from orders.
  delete from public.orders
  where id = any(v_order_ids);

  -- Delete target buyers' payments. For a multi-shop payment belonging to a
  -- different buyer, delete it only when no surviving order references it.
  delete from public.payment_transactions pt
  where pt.buyer_id = any(v_account_ids)
     or (
       pt.id = any(v_payment_ids)
       and not exists (
         select 1
         from public.orders o
         where o.payment_transaction_id = pt.id
       )
     );

  -- Profiles cascade to carts, favorites, shops, products, and product images.
  delete from public.profiles
  where id = any(v_account_ids);

  -- Finally remove login identities, sessions, and Auth user records.
  delete from auth.users
  where id = any(v_account_ids);

  get diagnostics v_deleted_count = row_count;
  raise notice 'Deleted % Auth account(s).', v_deleted_count;
end $$;

commit;

-- Auditable result: both rows should report "deleted or already absent".
select
  requested.email,
  case when u.id is null then 'deleted or already absent' else 'still present' end as result
from (
  values
    ('antoniorussel008@gmail.com'::text),
    ('jivan23leuterio@gmail.com'::text)
) requested(email)
left join auth.users u on lower(u.email) = requested.email
order by requested.email;
