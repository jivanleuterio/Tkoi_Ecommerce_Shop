-- Tkoi batched product marketplace statistics.
-- Additive and safe to rerun. Migration 03 replaces this function body
-- to include review aggregates after the review tables exist.

create or replace function public.get_product_stats(p_product_ids uuid[])
returns table (
  product_id uuid,
  sold_count bigint,
  heart_count bigint,
  average_rating numeric,
  total_reviews bigint,
  rating_5 bigint,
  rating_4 bigint,
  rating_3 bigint,
  rating_2 bigint,
  rating_1 bigint
)
language sql stable security definer set search_path=public as $$
  select
    p.id,
    coalesce((
      select sum(oi.quantity)::bigint
      from public.order_items oi
      join public.orders o on o.id=oi.order_id
      where oi.product_id=p.id and o.status='completed'
    ),0)::bigint,
    coalesce((
      select count(*)::bigint
      from public.product_favorites f
      where f.product_id=p.id
    ),0)::bigint,
    0::numeric,
    0::bigint,
    0::bigint,
    0::bigint,
    0::bigint,
    0::bigint,
    0::bigint
  from public.products p
  where p.id=any(coalesce(p_product_ids,'{}'::uuid[]));
$$;

revoke all on function public.get_product_stats(uuid[]) from public;
grant execute on function public.get_product_stats(uuid[]) to authenticated;

notify pgrst, 'reload schema';
