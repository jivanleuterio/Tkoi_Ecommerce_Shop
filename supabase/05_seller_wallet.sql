-- Tkoi seller wallet ledger and Xendit escrow.
-- Additive, safe to rerun, and intentionally excludes COD from wallet balances.

create table if not exists public.marketplace_settings (
  singleton boolean primary key default true check (singleton),
  platform_fee_percent numeric(5,2) not null default 5.00
    check (platform_fee_percent between 0 and 100),
  minimum_withdrawal numeric(12,2) not null default 100.00
    check (minimum_withdrawal > 0),
  auto_release_days integer not null default 7
    check (auto_release_days between 1 and 90),
  updated_at timestamptz not null default now()
);

insert into public.marketplace_settings(singleton)
values(true) on conflict(singleton) do nothing;

alter table public.orders add column if not exists shipped_at timestamptz;
alter table public.orders add column if not exists completed_at timestamptz;

create table if not exists public.seller_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  type text not null check (type in (
    'sale_pending','sale_released','platform_fee','refund_reversal',
    'withdrawal','withdrawal_reversal','adjustment'
  )),
  amount numeric(12,2) not null check (amount<>0),
  status text not null check (status in (
    'pending','available','reserved','settled','reversed'
  )),
  note text not null default '' check (char_length(note)<=500),
  created_at timestamptz not null default now()
);

create index if not exists seller_wallet_transactions_seller_idx
  on public.seller_wallet_transactions(seller_id,created_at desc);
create index if not exists seller_wallet_transactions_shop_idx
  on public.seller_wallet_transactions(shop_id,created_at desc);
create index if not exists seller_wallet_transactions_order_idx
  on public.seller_wallet_transactions(order_id);
create unique index if not exists seller_wallet_one_order_event_idx
  on public.seller_wallet_transactions(order_id,type)
  where order_id is not null and type in (
    'sale_pending','sale_released','platform_fee','refund_reversal'
  );

alter table public.marketplace_settings enable row level security;
alter table public.seller_wallet_transactions enable row level security;

revoke all on table public.marketplace_settings from anon,authenticated;
revoke all on table public.seller_wallet_transactions from anon;
revoke insert,update,delete on table public.seller_wallet_transactions
  from authenticated;
grant select on table public.seller_wallet_transactions to authenticated;

drop policy if exists "Sellers view own wallet ledger"
  on public.seller_wallet_transactions;
create policy "Sellers view own wallet ledger"
on public.seller_wallet_transactions for select to authenticated
using (seller_id=auth.uid());

-- The ledger is append-only even for privileged callers. Corrections are new
-- adjustment or reversal rows, never edits to historical entries.
create or replace function public.prevent_wallet_ledger_mutation()
returns trigger language plpgsql set search_path=public as $$
begin
  raise exception 'Wallet ledger entries are immutable. Append a reversal instead.';
end; $$;

drop trigger if exists seller_wallet_immutable
  on public.seller_wallet_transactions;
create trigger seller_wallet_immutable
before update or delete on public.seller_wallet_transactions
for each row execute function public.prevent_wallet_ledger_mutation();

create or replace function public.set_order_fulfillment_timestamps()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.status='shipped' and old.status is distinct from 'shipped'
     and new.shipped_at is null then
    new.shipped_at:=now();
  end if;
  if new.status='completed' and old.status is distinct from 'completed'
     and new.completed_at is null then
    new.completed_at:=now();
  end if;
  return new;
end; $$;

drop trigger if exists orders_set_fulfillment_timestamps on public.orders;
create trigger orders_set_fulfillment_timestamps
before update of status on public.orders
for each row execute function public.set_order_fulfillment_timestamps();

-- Returns were introduced by the separate order_aftercare migration. Keep the
-- wallet migration installable on older databases while still enforcing holds
-- as soon as that table exists.
create or replace function public.order_return_has_any_status(
  p_order_id uuid,
  p_statuses text[]
) returns boolean language plpgsql stable security definer set search_path=public as $$
declare v_found boolean:=false;
begin
  if to_regclass('public.order_returns') is null then return false; end if;
  execute 'select exists(
    select 1 from public.order_returns
    where order_id=$1 and status=any($2)
  )' into v_found using p_order_id,p_statuses;
  return v_found;
end; $$;

create or replace function public.record_xendit_sale_pending(p_order_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_fee_percent numeric(5,2);
  v_fee numeric(12,2);
  v_net numeric(12,2);
  v_inserted integer;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.payment_method<>'Xendit'
     or v_order.payment_status<>'paid' or v_order.status='cancelled' then
    return false;
  end if;

  select platform_fee_percent into v_fee_percent
  from public.marketplace_settings where singleton=true;
  v_fee:=round(v_order.total*v_fee_percent/100,2);
  v_net:=v_order.total-v_fee;
  if v_net<=0 then raise exception 'The configured fee leaves no seller proceeds.'; end if;

  insert into public.seller_wallet_transactions(
    shop_id,seller_id,order_id,type,amount,status,note
  ) values(
    v_order.shop_id,v_order.seller_id,v_order.id,'sale_pending',v_net,'pending',
    format('Xendit sale in escrow. Gross PHP %s, fee PHP %s.',v_order.total,v_fee)
  ) on conflict do nothing;
  get diagnostics v_inserted=row_count;

  if v_fee>0 then
    insert into public.seller_wallet_transactions(
      shop_id,seller_id,order_id,type,amount,status,note
    ) values(
      v_order.shop_id,v_order.seller_id,v_order.id,'platform_fee',-v_fee,'pending',
      format('Platform commission of %s%% on gross PHP %s.',v_fee_percent,v_order.total)
    ) on conflict do nothing;
  end if;
  return v_inserted>0;
end; $$;

create or replace function public.release_order_escrow(p_order_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_pending public.seller_wallet_transactions%rowtype;
  v_auto_days integer;
  v_inserted integer;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.payment_method<>'Xendit'
     or v_order.payment_status<>'paid' or v_order.status='cancelled' then
    return false;
  end if;
  select auto_release_days into v_auto_days
  from public.marketplace_settings where singleton=true;

  -- Until courier tracking exists, shipped_at + configured days is the
  -- fallback. Switch this to a trusted delivery event + 3 days later.
  if v_order.status<>'completed' and not (
    v_order.status='shipped' and v_order.shipped_at is not null
    and v_order.shipped_at+(v_auto_days||' days')::interval<=now()
  ) then return false; end if;

  if public.order_return_has_any_status(
    v_order.id,array['requested','approved','received']::text[]
  ) then return false; end if;
  if exists(
    select 1 from public.seller_wallet_transactions t
    where t.order_id=v_order.id and t.type in ('sale_released','refund_reversal')
  ) then return false; end if;

  select * into v_pending from public.seller_wallet_transactions t
  where t.order_id=v_order.id and t.type='sale_pending';
  if v_pending.id is null then return false; end if;

  insert into public.seller_wallet_transactions(
    shop_id,seller_id,order_id,type,amount,status,note
  ) values(
    v_order.shop_id,v_order.seller_id,v_order.id,'sale_released',
    v_pending.amount,'available','Escrow released to available balance.'
  ) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  return v_inserted>0;
end; $$;

create or replace function public.reverse_order_earnings(p_order_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare
  v_order public.orders%rowtype;
  v_pending public.seller_wallet_transactions%rowtype;
  v_released boolean;
  v_inserted integer;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or v_order.payment_method<>'Xendit' then return false; end if;
  select * into v_pending from public.seller_wallet_transactions t
  where t.order_id=v_order.id and t.type='sale_pending';
  if v_pending.id is null then return false; end if;
  select exists(
    select 1 from public.seller_wallet_transactions t
    where t.order_id=v_order.id and t.type='sale_released'
  ) into v_released;

  insert into public.seller_wallet_transactions(
    shop_id,seller_id,order_id,type,amount,status,note
  ) values(
    v_order.shop_id,v_order.seller_id,v_order.id,'refund_reversal',
    -v_pending.amount,case when v_released then 'available' else 'pending' end,
    case when v_released
      then 'Seller earnings reversed after buyer-favor return resolution.'
      else 'Pending escrow cancelled after buyer-favor return resolution.' end
  ) on conflict do nothing;
  get diagnostics v_inserted=row_count;
  return v_inserted>0;
end; $$;

create or replace function public.wallet_on_order_payment()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.payment_method='Xendit' and new.payment_status='paid'
     and old.payment_status is distinct from 'paid' then
    perform public.record_xendit_sale_pending(new.id);
  end if;
  return new;
end; $$;

drop trigger if exists orders_record_paid_wallet_sale on public.orders;
create trigger orders_record_paid_wallet_sale
after update of payment_status on public.orders
for each row execute function public.wallet_on_order_payment();

create or replace function public.wallet_on_order_completed()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='completed' and old.status is distinct from 'completed' then
    perform public.release_order_escrow(new.id);
  end if;
  return new;
end; $$;

drop trigger if exists orders_release_wallet_escrow on public.orders;
create trigger orders_release_wallet_escrow
after update of status on public.orders
for each row execute function public.wallet_on_order_completed();

create or replace function public.wallet_on_return_resolved()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='resolved' and old.status is distinct from 'resolved' then
    perform public.reverse_order_earnings(new.order_id);
  end if;
  return new;
end; $$;

do $$
begin
  if to_regclass('public.order_returns') is not null then
    execute 'drop trigger if exists order_returns_reverse_wallet on public.order_returns';
    execute 'create trigger order_returns_reverse_wallet '
      'after update of status on public.order_returns for each row '
      'execute function public.wallet_on_return_resolved()';
  end if;
end $$;

create or replace function public.release_due_seller_escrows()
returns integer language plpgsql security definer set search_path=public as $$
declare v_order_id uuid; v_count integer:=0;
begin
  for v_order_id in
    select o.id from public.orders o,public.marketplace_settings s
    where s.singleton=true and o.payment_method='Xendit'
      and o.payment_status='paid' and o.status='shipped'
      and o.shipped_at is not null
      and o.shipped_at+(s.auto_release_days||' days')::interval<=now()
      and not public.order_return_has_any_status(
        o.id,array['requested','approved','received']::text[]
      )
  loop
    if public.release_order_escrow(v_order_id) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end; $$;

create or replace function public.get_seller_wallet_summary(p_shop_id uuid)
returns table(
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  minimum_withdrawal numeric,
  platform_fee_percent numeric,
  auto_release_days integer
) language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query
  select
    coalesce(sum(t.amount) filter(where t.type in (
      'sale_released','refund_reversal','withdrawal','withdrawal_reversal','adjustment'
    ) and t.status<>'pending'),0)::numeric(12,2),
    coalesce(sum(t.amount) filter(where t.type='sale_pending'
      and not exists(select 1 from public.seller_wallet_transactions closed
        where closed.order_id=t.order_id
          and closed.type in ('sale_released','refund_reversal'))),0)::numeric(12,2),
    coalesce(sum(t.amount) filter(where t.type='sale_released'),0)::numeric(12,2),
    greatest(0,-coalesce(sum(t.amount) filter(where t.type in (
      'withdrawal','withdrawal_reversal'
    )),0))::numeric(12,2),
    settings.minimum_withdrawal,settings.platform_fee_percent,
    settings.auto_release_days
  from public.marketplace_settings settings
  left join public.seller_wallet_transactions t on t.shop_id=p_shop_id
  where settings.singleton=true
  group by settings.minimum_withdrawal,settings.platform_fee_percent,
    settings.auto_release_days;
end; $$;

create or replace function public.get_seller_wallet_transactions(
  p_shop_id uuid,p_filter text default 'all'
) returns table(
  id uuid,order_id uuid,type text,amount numeric,status text,note text,
  created_at timestamptz
) language plpgsql stable security definer set search_path=public as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query select t.id,t.order_id,t.type,t.amount,t.status,t.note,t.created_at
  from public.seller_wallet_transactions t where t.shop_id=p_shop_id and (
    p_filter='all'
    or (p_filter='earnings' and t.type in ('sale_pending','sale_released'))
    or (p_filter='fees' and t.type='platform_fee')
    or (p_filter='withdrawals' and t.type in ('withdrawal','withdrawal_reversal'))
    or (p_filter='refunds' and t.type='refund_reversal')
  ) order by t.created_at desc;
end; $$;

-- Preview first. This never writes and reports precisely what the manual
-- backfill would inspect and how many orders do not yet have a ledger entry.
create or replace function public.preview_seller_wallet_backfill()
returns table(
  eligible_paid_orders bigint,
  orders_without_ledger bigint,
  completed_or_due bigint,
  held_by_active_return bigint
) language sql stable security definer set search_path=public as $$
  select
    count(*)::bigint,
    count(*) filter(where pending.id is null)::bigint,
    count(*) filter(where o.status='completed' or (
      o.status='shipped' and o.shipped_at is not null
      and o.shipped_at+(settings.auto_release_days||' days')::interval<=now()
    ))::bigint,
    count(*) filter(where public.order_return_has_any_status(
      o.id,array['requested','approved','received']::text[]
    ))::bigint
  from public.orders o
  cross join public.marketplace_settings settings
  left join public.seller_wallet_transactions pending
    on pending.order_id=o.id and pending.type='sale_pending'
  where settings.singleton=true and o.payment_method='Xendit'
    and o.payment_status='paid' and o.status<>'cancelled';
$$;

create or replace function public.backfill_seller_wallet()
returns integer language plpgsql security definer set search_path=public as $$
declare v_order record; v_count integer:=0;
begin
  for v_order in select o.id,o.status from public.orders o
    where o.payment_method='Xendit' and o.payment_status='paid'
      and o.status<>'cancelled'
  loop
    if public.record_xendit_sale_pending(v_order.id) then v_count:=v_count+1; end if;
    if public.order_return_has_any_status(
      v_order.id,array['resolved']::text[]
    ) then
      perform public.reverse_order_earnings(v_order.id);
    elsif v_order.status='completed' then
      perform public.release_order_escrow(v_order.id);
    end if;
  end loop;
  perform public.release_due_seller_escrows();
  return v_count;
end; $$;

revoke all on function public.record_xendit_sale_pending(uuid) from public;
revoke all on function public.release_order_escrow(uuid) from public;
revoke all on function public.reverse_order_earnings(uuid) from public;
revoke all on function public.release_due_seller_escrows() from public;
revoke all on function public.preview_seller_wallet_backfill() from public;
revoke all on function public.backfill_seller_wallet() from public;
revoke all on function public.get_seller_wallet_summary(uuid) from public;
revoke all on function public.get_seller_wallet_transactions(uuid,text) from public;
revoke all on function public.order_return_has_any_status(uuid,text[]) from public;
grant execute on function public.get_seller_wallet_summary(uuid) to authenticated;
grant execute on function public.get_seller_wallet_transactions(uuid,text) to authenticated;
grant execute on function public.record_xendit_sale_pending(uuid) to service_role;
grant execute on function public.release_order_escrow(uuid) to service_role;
grant execute on function public.reverse_order_earnings(uuid) to service_role;
grant execute on function public.release_due_seller_escrows() to service_role;
grant execute on function public.preview_seller_wallet_backfill() to service_role;
grant execute on function public.backfill_seller_wallet() to service_role;

notify pgrst,'reload schema';
