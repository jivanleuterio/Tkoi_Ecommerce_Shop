begin;
drop function if exists public.get_seller_dashboard_stats(uuid,integer);
drop function if exists public.get_seller_orders_secure(uuid);
commit;
notify pgrst,'reload schema';
