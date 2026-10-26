-- Tkoi batched admin dashboard metrics and 30-day order/revenue series.
-- Run after 15_admin_operations.sql. Additive and safe to run twice.

create or replace function public.get_admin_dashboard_stats()
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.is_admin() then raise exception 'Admin access required.'; end if;
  return jsonb_build_object(
    'total_users',case when public.has_admin_permission('users.view')
      or public.has_admin_permission('users.suspend')
      then (select count(*) from public.profiles) else 0 end,
    'new_users_7d',case when public.has_admin_permission('users.view')
      or public.has_admin_permission('users.suspend')
      then (select count(*) from public.profiles p
        where p.created_at>=now()-interval '7 days') else 0 end,
    'total_shops',case when public.has_admin_permission('content.moderate')
      then (select count(*) from public.shops) else 0 end,
    'active_listings',case when public.has_admin_permission('content.moderate')
      then (select count(*) from public.products p
      join public.shops s on s.id=p.shop_id
      where p.status='available' and p.quantity>0
        and p.moderation_status='clear' and s.moderation_status='clear') else 0 end,
    'orders_7d',case when public.has_admin_permission('orders.view')
      then (select count(*) from public.orders o
        where o.created_at>=now()-interval '7 days') else 0 end,
    'revenue_7d',case when public.has_admin_permission('orders.view')
      then (select coalesce(sum(o.total),0) from public.orders o
        where o.status='completed' and coalesce(o.completed_at,o.updated_at)>=now()-interval '7 days') else 0 end,
    'orders_30d',case when public.has_admin_permission('orders.view')
      then (select count(*) from public.orders o
        where o.created_at>=now()-interval '30 days') else 0 end,
    'revenue_30d',case when public.has_admin_permission('orders.view')
      then (select coalesce(sum(o.total),0) from public.orders o
        where o.status='completed' and coalesce(o.completed_at,o.updated_at)>=now()-interval '30 days') else 0 end,
    'open_tickets',case when public.has_admin_permission('tickets.view')
      then (select count(*) from public.support_tickets t
        where t.status in ('open','in_progress','waiting_user')) else 0 end,
    'open_reports',case when public.has_admin_permission('reports.view')
      then (select count(*) from public.reports r
        where r.status in ('open','reviewing')) else 0 end,
    'pending_returns',case when public.has_admin_permission('returns.decide')
      then (select count(*) from public.order_returns r
        where r.status in ('requested','approved','received')) else 0 end,
    'pending_withdrawals',case when public.has_admin_permission('withdrawals.view')
      then (select count(*) from public.withdrawal_requests w
        where w.status in ('pending','approved')) else 0 end,
    'suspended_users',case when public.has_admin_permission('users.suspend')
      then (select count(*) from public.account_controls c
        where c.status='suspended' and (c.suspended_until is null or c.suspended_until>now())) else 0 end,
    'banned_users',case when public.has_admin_permission('users.suspend')
      then (select count(*) from public.account_controls c where c.status='banned') else 0 end,
    'negative_balance_shops',case when public.has_admin_permission('wallet.view')
      then (select count(*) from (
      select t.shop_id from public.seller_wallet_transactions t
      group by t.shop_id having coalesce(sum(t.amount) filter(where t.type in (
        'sale_released','refund_reversal','withdrawal','withdrawal_reversal','adjustment'
      ) and t.status<>'pending'),0)<0
    ) negative) else 0 end,
    'sales_points',case when public.has_admin_permission('orders.view') then
      coalesce((select jsonb_agg(jsonb_build_object(
      'day',days.day,
      'orders',coalesce(metrics.orders,0),
      'revenue',coalesce(metrics.revenue,0)
    ) order by days.day)
    from generate_series(current_date-29,current_date,'1 day') days(day)
    left join lateral(
      select count(*) orders,
        coalesce(sum(o.total) filter(where o.status='completed'),0) revenue
      from public.orders o where o.created_at::date=days.day::date
    ) metrics on true),'[]'::jsonb) else '[]'::jsonb end
  );
end; $$;

revoke all on function public.get_admin_dashboard_stats() from public,anon;
grant execute on function public.get_admin_dashboard_stats() to authenticated;

notify pgrst,'reload schema';
