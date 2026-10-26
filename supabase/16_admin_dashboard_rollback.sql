-- Roll back only objects created by 16_admin_dashboard.sql.
drop function if exists public.get_admin_dashboard_stats();
notify pgrst,'reload schema';
