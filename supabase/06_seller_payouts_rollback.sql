-- Roll back only migration 06. This deletes payout and withdrawal history.
begin;
drop function if exists public.request_demo_seller_withdrawal(uuid,numeric,uuid);
drop function if exists public.get_seller_withdrawals(uuid);
drop function if exists public.get_seller_payout_accounts(uuid);
drop function if exists public.admin_process_withdrawal(uuid,text,text,text);
drop function if exists public.cancel_seller_withdrawal(uuid);
drop function if exists public.request_seller_withdrawal(uuid,numeric,uuid);
drop function if exists public.delete_seller_payout_account(uuid);
drop function if exists public.save_seller_payout_account(uuid,uuid,text,text,text,text,boolean);
drop index if exists public.seller_wallet_one_withdrawal_event_idx;
alter table public.seller_wallet_transactions
  drop column if exists withdrawal_request_id;
drop table if exists public.withdrawal_requests;
drop table if exists public.seller_payout_accounts;
alter table public.marketplace_settings
  drop column if exists demo_withdrawals_enabled;
commit;
notify pgrst,'reload schema';
