-- Tkoi demo payout-account save hotfix.
-- Run after 06_seller_payouts.sql. Additive and safe to run twice.
-- Demo payout details are text records only; no phone/provider verification.

-- Demo accounts accept any non-empty identifier (up to 100 characters).
-- This value is stored only; Tkoi does not contact GCash or a bank.
alter table public.seller_payout_accounts
  drop constraint if exists seller_payout_accounts_account_number_check;
alter table public.seller_payout_accounts
  drop constraint if exists seller_payout_demo_account_number_check;
alter table public.seller_payout_accounts
  add constraint seller_payout_demo_account_number_check check (
    char_length(trim(account_number)) between 1 and 100
  ) not valid;

create or replace function public.save_demo_seller_payout_account(
  p_shop_id uuid,
  p_account_id uuid,
  p_method text,
  p_account_name text,
  p_account_number text,
  p_bank_name text default null,
  p_is_default boolean default false
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if not exists(select 1 from public.shops s
    where s.id=p_shop_id and s.owner_id=v_user) then
    raise exception 'Shop not found.';
  end if;
  if p_method not in ('gcash','bank') then raise exception 'Choose GCash or bank.'; end if;
  if char_length(trim(coalesce(p_account_name,''))) not between 2 and 100 then
    raise exception 'Enter the payout account holder name.';
  end if;
  if char_length(trim(coalesce(p_account_number,''))) not between 1 and 100 then
    raise exception 'Enter an account number or demo identifier.';
  end if;
  if p_method='bank' and char_length(trim(coalesce(p_bank_name,''))) not between 2 and 100 then
    raise exception 'Enter the bank name.';
  end if;

  if p_is_default then
    update public.seller_payout_accounts set is_default=false
    where shop_id=p_shop_id and seller_id=v_user and is_default;
  end if;

  if p_account_id is null then
    insert into public.seller_payout_accounts(
      shop_id,seller_id,method,account_name,account_number,bank_name,is_default
    ) values(
      p_shop_id,v_user,p_method,trim(p_account_name),trim(p_account_number),
      case when p_method='bank' then trim(p_bank_name) else null end,
      p_is_default or not exists(select 1 from public.seller_payout_accounts
        where shop_id=p_shop_id and seller_id=v_user)
    ) returning id into v_id;
  else
    update public.seller_payout_accounts set
      method=p_method,account_name=trim(p_account_name),
      account_number=trim(p_account_number),
      bank_name=case when p_method='bank' then trim(p_bank_name) else null end,
      is_default=p_is_default
    where id=p_account_id and shop_id=p_shop_id and seller_id=v_user
    returning id into v_id;
    if v_id is null then raise exception 'Payout account not found.'; end if;
  end if;
  return v_id;
end; $$;

revoke all on function public.save_demo_seller_payout_account(
  uuid,uuid,text,text,text,text,boolean
) from public;
grant execute on function public.save_demo_seller_payout_account(
  uuid,uuid,text,text,text,text,boolean
) to authenticated;

notify pgrst,'reload schema';
