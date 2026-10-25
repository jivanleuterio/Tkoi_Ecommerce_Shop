-- Tkoi seller payout accounts and manual withdrawal workflow.
-- Additive, safe to rerun. No automatic Xendit disbursement is performed.

alter table public.marketplace_settings
  add column if not exists demo_withdrawals_enabled boolean not null default true;

-- Older Tkoi databases may not have run security_hardening.sql. Define the
-- same server-side helper here so payout security never depends on migration
-- history or on a client-provided verification flag.
create or replace function public.is_phone_verified(
  target_user uuid default auth.uid()
) returns boolean language sql stable security definer
set search_path=public,auth as $$
  select exists(
    select 1 from auth.users u
    where u.id=target_user and u.phone is not null
      and u.phone_confirmed_at is not null
  );
$$;
revoke all on function public.is_phone_verified(uuid) from public;
grant execute on function public.is_phone_verified(uuid) to authenticated;

create table if not exists public.seller_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  method text not null check (method in ('gcash','bank')),
  account_name text not null check (char_length(trim(account_name)) between 2 and 100),
  account_number text not null check (account_number~'^[0-9]{8,24}$'),
  bank_name text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint seller_payout_bank_name check (
    (method='gcash' and bank_name is null)
    or (method='bank' and char_length(trim(bank_name)) between 2 and 100)
  )
);

create unique index if not exists seller_payout_one_default_idx
  on public.seller_payout_accounts(shop_id) where is_default;
create index if not exists seller_payout_accounts_seller_idx
  on public.seller_payout_accounts(seller_id,created_at desc);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  payout_account_id uuid references public.seller_payout_accounts(id) on delete set null,
  amount numeric(12,2) not null check (amount>0),
  payout_method text not null check (payout_method in ('gcash','bank')),
  account_name_snapshot text not null,
  account_number_snapshot text not null,
  bank_name_snapshot text,
  status text not null default 'pending' check (status in (
    'pending','approved','paid','rejected','cancelled'
  )),
  admin_note text not null default '' check (char_length(admin_note)<=500),
  external_reference text,
  is_demo boolean not null default false,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.withdrawal_requests
  add column if not exists is_demo boolean not null default false;

create unique index if not exists withdrawal_one_pending_per_shop_idx
  on public.withdrawal_requests(shop_id) where status='pending';
create index if not exists withdrawal_requests_seller_idx
  on public.withdrawal_requests(seller_id,requested_at desc);
create index if not exists withdrawal_requests_status_idx
  on public.withdrawal_requests(status,requested_at);

alter table public.seller_wallet_transactions
  add column if not exists withdrawal_request_id uuid
    references public.withdrawal_requests(id) on delete restrict;
create unique index if not exists seller_wallet_one_withdrawal_event_idx
  on public.seller_wallet_transactions(withdrawal_request_id,type)
  where withdrawal_request_id is not null
    and type in ('withdrawal','withdrawal_reversal');

drop trigger if exists seller_payout_accounts_set_updated_at
  on public.seller_payout_accounts;
create trigger seller_payout_accounts_set_updated_at
before update on public.seller_payout_accounts
for each row execute function public.set_updated_at();
drop trigger if exists withdrawal_requests_set_updated_at
  on public.withdrawal_requests;
create trigger withdrawal_requests_set_updated_at
before update on public.withdrawal_requests
for each row execute function public.set_updated_at();

alter table public.seller_payout_accounts enable row level security;
alter table public.withdrawal_requests enable row level security;
revoke all on table public.seller_payout_accounts from anon;
revoke all on table public.withdrawal_requests from anon;
revoke insert,update,delete on table public.seller_payout_accounts from authenticated;
revoke insert,update,delete on table public.withdrawal_requests from authenticated;
grant select on table public.seller_payout_accounts to authenticated;
grant select on table public.withdrawal_requests to authenticated;

drop policy if exists "Sellers view own payout accounts"
  on public.seller_payout_accounts;
create policy "Sellers view own payout accounts"
on public.seller_payout_accounts for select to authenticated
using (seller_id=auth.uid());
drop policy if exists "Sellers view own withdrawals"
  on public.withdrawal_requests;
create policy "Sellers view own withdrawals"
on public.withdrawal_requests for select to authenticated
using (seller_id=auth.uid());

create or replace function public.save_seller_payout_account(
  p_shop_id uuid,p_account_id uuid,p_method text,p_account_name text,
  p_account_number text,p_bank_name text default null,p_is_default boolean default false
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
  v_demo_enabled boolean;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  select demo_withdrawals_enabled into v_demo_enabled
  from public.marketplace_settings where singleton=true;
  if not coalesce(v_demo_enabled,false)
     and not public.is_phone_verified(v_user) then
    raise exception 'Verify your phone before adding a payout account.';
  end if;
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=v_user) then
    raise exception 'Shop not found.';
  end if;
  if p_method not in ('gcash','bank') then raise exception 'Choose GCash or bank.'; end if;
  if char_length(trim(coalesce(p_account_name,''))) not between 2 and 100 then
    raise exception 'Enter the payout account holder name.';
  end if;
  if coalesce(p_account_number,'')!~'^[0-9]{8,24}$' then
    raise exception 'Enter a valid account number using digits only.';
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
      p_shop_id,v_user,p_method,trim(p_account_name),p_account_number,
      case when p_method='bank' then trim(p_bank_name) else null end,
      p_is_default or not exists(
        select 1 from public.seller_payout_accounts where shop_id=p_shop_id
      )
    ) returning id into v_id;
  else
    update public.seller_payout_accounts set
      method=p_method,account_name=trim(p_account_name),
      account_number=p_account_number,
      bank_name=case when p_method='bank' then trim(p_bank_name) else null end,
      is_default=p_is_default
    where id=p_account_id and shop_id=p_shop_id and seller_id=v_user
    returning id into v_id;
    if v_id is null then raise exception 'Payout account not found.'; end if;
  end if;
  return v_id;
end; $$;

create or replace function public.delete_seller_payout_account(p_account_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_shop uuid; v_was_default boolean;
begin
  if exists(select 1 from public.withdrawal_requests w
    where w.payout_account_id=p_account_id and w.seller_id=v_user
      and w.status in ('pending','approved')) then
    raise exception 'This account is being used by an active withdrawal.';
  end if;
  select shop_id,is_default into v_shop,v_was_default
  from public.seller_payout_accounts
  where id=p_account_id and seller_id=v_user for update;
  if v_shop is null then raise exception 'Payout account not found.'; end if;
  delete from public.seller_payout_accounts where id=p_account_id;
  if v_was_default then
    update public.seller_payout_accounts set is_default=true
    where id=(select id from public.seller_payout_accounts
      where shop_id=v_shop and seller_id=v_user order by created_at limit 1);
  end if;
end; $$;

create or replace function public.request_seller_withdrawal(
  p_shop_id uuid,p_amount numeric,p_payout_account_id uuid
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_account public.seller_payout_accounts%rowtype;
  v_available numeric(12,2);
  v_minimum numeric(12,2);
  v_request_id uuid;
  v_demo_enabled boolean;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  select demo_withdrawals_enabled into v_demo_enabled
  from public.marketplace_settings where singleton=true;
  if not coalesce(v_demo_enabled,false)
     and not public.is_phone_verified(v_user) then
    raise exception 'Verify your phone before requesting a withdrawal.';
  end if;
  perform 1 from public.shops s where s.id=p_shop_id and s.owner_id=v_user for update;
  if not found then raise exception 'Shop not found.'; end if;
  if p_amount is null or p_amount<=0 or round(p_amount,2)<>p_amount then
    raise exception 'Enter a valid withdrawal amount with up to two decimal places.';
  end if;
  select * into v_account from public.seller_payout_accounts
  where id=p_payout_account_id and shop_id=p_shop_id and seller_id=v_user;
  if v_account.id is null then raise exception 'Payout account not found.'; end if;
  if exists(select 1 from public.withdrawal_requests
    where shop_id=p_shop_id and status='pending') then
    raise exception 'You already have a pending withdrawal request.';
  end if;
  select minimum_withdrawal into v_minimum
  from public.marketplace_settings where singleton=true;
  select coalesce(sum(t.amount),0)::numeric(12,2) into v_available
  from public.seller_wallet_transactions t where t.shop_id=p_shop_id
    and t.type in (
      'sale_released','refund_reversal','withdrawal','withdrawal_reversal','adjustment'
    ) and t.status<>'pending';
  if v_available<0 then
    raise exception 'Withdrawals are blocked while your available balance is negative after a refund reversal.';
  end if;
  if p_amount<v_minimum then
    raise exception 'The minimum withdrawal is PHP %.',v_minimum;
  end if;
  if p_amount>v_available then raise exception 'Withdrawal exceeds available balance.'; end if;

  insert into public.withdrawal_requests(
    shop_id,seller_id,payout_account_id,amount,payout_method,
    account_name_snapshot,account_number_snapshot,bank_name_snapshot
  ) values(
    p_shop_id,v_user,v_account.id,p_amount,v_account.method,
    v_account.account_name,v_account.account_number,v_account.bank_name
  ) returning id into v_request_id;
  insert into public.seller_wallet_transactions(
    shop_id,seller_id,withdrawal_request_id,type,amount,status,note
  ) values(
    p_shop_id,v_user,v_request_id,'withdrawal',-p_amount,'reserved',
    'Funds reserved for withdrawal request.'
  );
  return v_request_id;
end; $$;

create or replace function public.cancel_seller_withdrawal(p_withdrawal_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_request public.withdrawal_requests%rowtype;
begin
  select * into v_request from public.withdrawal_requests
  where id=p_withdrawal_id and seller_id=auth.uid() for update;
  if v_request.id is null then raise exception 'Withdrawal request not found.'; end if;
  if v_request.status<>'pending' then
    raise exception 'Only a pending withdrawal can be cancelled.';
  end if;
  update public.withdrawal_requests set status='cancelled',processed_at=now()
  where id=v_request.id;
  insert into public.seller_wallet_transactions(
    shop_id,seller_id,withdrawal_request_id,type,amount,status,note
  ) values(
    v_request.shop_id,v_request.seller_id,v_request.id,
    'withdrawal_reversal',v_request.amount,'available',
    'Cancelled withdrawal returned to available balance.'
  ) on conflict do nothing;
end; $$;

create or replace function public.admin_process_withdrawal(
  p_withdrawal_id uuid,p_action text,p_admin_note text default null,
  p_external_reference text default null
) returns void language plpgsql security definer set search_path=public as $$
declare v_request public.withdrawal_requests%rowtype;
begin
  select * into v_request from public.withdrawal_requests
  where id=p_withdrawal_id for update;
  if v_request.id is null then raise exception 'Withdrawal request not found.'; end if;
  if p_action='approve' then
    if v_request.status<>'pending' then raise exception 'Only pending requests can be approved.'; end if;
    update public.withdrawal_requests set status='approved',
      admin_note=left(coalesce(p_admin_note,''),500),
      external_reference=nullif(trim(p_external_reference),'')
    where id=v_request.id;
  elsif p_action='paid' then
    if v_request.status<>'approved' then raise exception 'Approve the request before marking it paid.'; end if;
    update public.withdrawal_requests set status='paid',processed_at=now(),
      admin_note=left(coalesce(p_admin_note,admin_note),500),
      external_reference=coalesce(nullif(trim(p_external_reference),''),external_reference)
    where id=v_request.id;
  elsif p_action='reject' then
    if v_request.status not in ('pending','approved') then
      raise exception 'Only pending or approved requests can be rejected.';
    end if;
    update public.withdrawal_requests set status='rejected',processed_at=now(),
      admin_note=left(coalesce(p_admin_note,''),500),
      external_reference=coalesce(nullif(trim(p_external_reference),''),external_reference)
    where id=v_request.id;
    insert into public.seller_wallet_transactions(
      shop_id,seller_id,withdrawal_request_id,type,amount,status,note
    ) values(
      v_request.shop_id,v_request.seller_id,v_request.id,
      'withdrawal_reversal',v_request.amount,'available',
      'Rejected withdrawal returned to available balance.'
    ) on conflict do nothing;
  else
    raise exception 'Action must be approve, paid, or reject.';
  end if;
end; $$;

-- Demo-only withdrawal. This performs all checks in
-- request_seller_withdrawal(), then marks the request paid inside the same
-- transaction. It changes only the Tkoi ledger; it never sends real money.
create or replace function public.request_demo_seller_withdrawal(
  p_shop_id uuid,p_amount numeric,p_payout_account_id uuid
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_request_id uuid;
begin
  if not coalesce((select demo_withdrawals_enabled
    from public.marketplace_settings where singleton=true),false) then
    raise exception 'Demo withdrawals are disabled.';
  end if;

  v_request_id:=public.request_seller_withdrawal(
    p_shop_id,p_amount,p_payout_account_id
  );
  update public.withdrawal_requests set
    status='paid',processed_at=now(),is_demo=true,
    admin_note='Demo withdrawal only. No real funds were transferred.',
    external_reference='DEMO-'||upper(left(v_request_id::text,8))
  where id=v_request_id;
  return v_request_id;
end; $$;

create or replace function public.get_seller_payout_accounts(p_shop_id uuid)
returns setof public.seller_payout_accounts
language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query select * from public.seller_payout_accounts
  where shop_id=p_shop_id and seller_id=auth.uid()
  order by is_default desc,created_at;
end; $$;

create or replace function public.get_seller_withdrawals(p_shop_id uuid)
returns setof public.withdrawal_requests
language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query select * from public.withdrawal_requests
  where shop_id=p_shop_id and seller_id=auth.uid()
  order by requested_at desc;
end; $$;

-- Replace the summary so "withdrawn" means requests actually marked paid.
create or replace function public.get_seller_wallet_summary(p_shop_id uuid)
returns table(
  available_balance numeric,pending_balance numeric,total_earned numeric,
  total_withdrawn numeric,minimum_withdrawal numeric,
  platform_fee_percent numeric,auto_release_days integer
) language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query
  with ledger as (
    select
      coalesce(sum(t.amount) filter(where t.type in (
        'sale_released','refund_reversal','withdrawal','withdrawal_reversal','adjustment'
      ) and t.status<>'pending'),0)::numeric(12,2) available,
      coalesce(sum(t.amount) filter(where t.type='sale_released'),0)::numeric(12,2) earned
    from public.seller_wallet_transactions t where t.shop_id=p_shop_id
  ), pending as (
    select coalesce(sum(t.amount),0)::numeric(12,2) amount
    from public.seller_wallet_transactions t
    where t.shop_id=p_shop_id and t.type='sale_pending'
      and not exists(select 1 from public.seller_wallet_transactions closed
        where closed.order_id=t.order_id
          and closed.type in ('sale_released','refund_reversal'))
  ), withdrawn as (
    select coalesce(sum(w.amount),0)::numeric(12,2) amount
    from public.withdrawal_requests w
    where w.shop_id=p_shop_id and w.status='paid'
  )
  select ledger.available,pending.amount,ledger.earned,withdrawn.amount,
    settings.minimum_withdrawal,settings.platform_fee_percent,
    settings.auto_release_days
  from ledger,pending,withdrawn,public.marketplace_settings settings
  where settings.singleton=true;
end; $$;

revoke all on function public.save_seller_payout_account(uuid,uuid,text,text,text,text,boolean) from public;
revoke all on function public.delete_seller_payout_account(uuid) from public;
revoke all on function public.request_seller_withdrawal(uuid,numeric,uuid) from public;
revoke all on function public.cancel_seller_withdrawal(uuid) from public;
revoke all on function public.admin_process_withdrawal(uuid,text,text,text) from public;
revoke all on function public.request_demo_seller_withdrawal(uuid,numeric,uuid) from public;
revoke all on function public.get_seller_payout_accounts(uuid) from public;
revoke all on function public.get_seller_withdrawals(uuid) from public;
grant execute on function public.save_seller_payout_account(uuid,uuid,text,text,text,text,boolean) to authenticated;
grant execute on function public.delete_seller_payout_account(uuid) to authenticated;
grant execute on function public.request_seller_withdrawal(uuid,numeric,uuid) to authenticated;
grant execute on function public.cancel_seller_withdrawal(uuid) to authenticated;
grant execute on function public.request_demo_seller_withdrawal(uuid,numeric,uuid) to authenticated;
grant execute on function public.get_seller_payout_accounts(uuid) to authenticated;
grant execute on function public.get_seller_withdrawals(uuid) to authenticated;
grant execute on function public.admin_process_withdrawal(uuid,text,text,text) to service_role;

notify pgrst,'reload schema';
