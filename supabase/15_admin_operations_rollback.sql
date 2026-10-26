-- Roll back only objects introduced by 15_admin_operations.sql.

drop function if exists public.admin_list_audit_log(text,uuid,text);
drop function if exists public.admin_update_marketplace_settings(numeric,numeric,integer,boolean,text);
drop function if exists public.get_admin_marketplace_settings();
drop function if exists public.admin_get_wallet_ledger(uuid);
drop function if exists public.admin_list_wallets();
drop function if exists public.admin_reveal_withdrawal_account(uuid,text);
drop function if exists public.admin_list_withdrawals(text);
drop function if exists public.admin_process_withdrawal_authenticated(uuid,text,text,text,text);
drop function if exists public.process_withdrawal_internal(uuid,text,text,text,uuid);
drop function if exists public.admin_decide_return(uuid,text,text,text);
drop function if exists public.admin_list_returns(text);
drop function if exists public.apply_return_status_transition(uuid,text,boolean);
drop function if exists public.admin_reveal_order_address(uuid,text);
drop function if exists public.admin_get_order_detail(uuid);
drop function if exists public.admin_list_orders(text,text);

alter table if exists public.order_returns
  drop column if exists admin_note,
  drop column if exists decided_by,
  drop column if exists decided_at;
alter table if exists public.withdrawal_requests
  drop column if exists processed_by;
alter table if exists public.marketplace_settings
  drop column if exists demo_mode;

notify pgrst,'reload schema';
