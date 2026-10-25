-- Roll back only migration 08.
drop function if exists public.save_demo_seller_payout_account(
  uuid,uuid,text,text,text,text,boolean
);
alter table if exists public.seller_payout_accounts
  drop constraint if exists seller_payout_demo_account_number_check;
alter table if exists public.seller_payout_accounts
  add constraint seller_payout_accounts_account_number_check check (
    account_number~'^[0-9]{8,24}$'
  ) not valid;
notify pgrst,'reload schema';
