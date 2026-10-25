-- Tkoi self-contained demo withdrawal installer.
-- Run after 05_seller_wallet.sql, 06_seller_payouts.sql, and
-- 08_demo_payout_accounts.sql. Additive and safe to run twice.
-- No real GCash/bank transfer is performed.

alter table public.marketplace_settings
  add column if not exists demo_withdrawals_enabled boolean not null default true;

alter table public.withdrawal_requests
  add column if not exists is_demo boolean not null default false;

alter table public.seller_wallet_transactions
  add column if not exists withdrawal_request_id uuid
    references public.withdrawal_requests(id) on delete restrict;

create unique index if not exists seller_wallet_one_withdrawal_event_idx
  on public.seller_wallet_transactions(withdrawal_request_id,type)
  where withdrawal_request_id is not null
    and type in ('withdrawal','withdrawal_reversal');

create or replace function public.request_demo_seller_withdrawal(
  p_shop_id uuid,
  p_amount numeric,
  p_payout_account_id uuid
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_account public.seller_payout_accounts%rowtype;
  v_available numeric(12,2);
  v_minimum numeric(12,2);
  v_request_id uuid:=gen_random_uuid();
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if not coalesce((select demo_withdrawals_enabled
    from public.marketplace_settings where singleton=true),false) then
    raise exception 'Demo withdrawals are disabled.';
  end if;

  perform 1 from public.shops s
  where s.id=p_shop_id and s.owner_id=v_user for update;
  if not found then raise exception 'Shop not found.'; end if;

  if p_amount is null or p_amount<=0 or round(p_amount,2)<>p_amount then
    raise exception 'Enter a valid withdrawal amount with up to two decimal places.';
  end if;

  select * into v_account from public.seller_payout_accounts
  where id=p_payout_account_id and shop_id=p_shop_id and seller_id=v_user;
  if v_account.id is null then raise exception 'Payout account not found.'; end if;

  if exists(select 1 from public.withdrawal_requests
    where shop_id=p_shop_id and status in ('pending','approved')) then
    raise exception 'You already have an active withdrawal request.';
  end if;

  select minimum_withdrawal into v_minimum
  from public.marketplace_settings where singleton=true;

  select coalesce(sum(t.amount),0)::numeric(12,2) into v_available
  from public.seller_wallet_transactions t
  where t.shop_id=p_shop_id
    and t.type in (
      'sale_released','refund_reversal','withdrawal',
      'withdrawal_reversal','adjustment'
    )
    and t.status<>'pending';

  if v_available<0 then
    raise exception 'Withdrawals are blocked while your available balance is negative after a refund reversal.';
  end if;
  if p_amount<v_minimum then
    raise exception 'The minimum withdrawal is PHP %.',v_minimum;
  end if;
  if p_amount>v_available then
    raise exception 'Withdrawal exceeds available balance.';
  end if;

  insert into public.withdrawal_requests(
    id,shop_id,seller_id,payout_account_id,amount,payout_method,
    account_name_snapshot,account_number_snapshot,bank_name_snapshot,
    status,admin_note,external_reference,is_demo,processed_at
  ) values(
    v_request_id,p_shop_id,v_user,v_account.id,p_amount,v_account.method,
    v_account.account_name,v_account.account_number,v_account.bank_name,
    'paid','Demo withdrawal only. No real funds were transferred.',
    'DEMO-'||upper(left(v_request_id::text,8)),true,now()
  );

  insert into public.seller_wallet_transactions(
    shop_id,seller_id,withdrawal_request_id,type,amount,status,note
  ) values(
    p_shop_id,v_user,v_request_id,'withdrawal',-p_amount,'settled',
    'Demo withdrawal deducted from the Tkoi wallet. No real funds were transferred.'
  );

  return v_request_id;
end; $$;

revoke all on function public.request_demo_seller_withdrawal(
  uuid,numeric,uuid
) from public;
grant execute on function public.request_demo_seller_withdrawal(
  uuid,numeric,uuid
) to authenticated;

notify pgrst,'reload schema';
