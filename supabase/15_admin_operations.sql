-- Tkoi admin orders, returns, withdrawals, wallet, settings, and audit tools.
-- Run after 14_content_moderation.sql. Additive and safe to run twice.

alter table public.marketplace_settings
  add column if not exists demo_mode boolean not null default true;
update public.marketplace_settings set demo_mode=demo_withdrawals_enabled
where singleton=true and demo_mode is distinct from demo_withdrawals_enabled;

alter table public.withdrawal_requests
  add column if not exists processed_by uuid references auth.users(id) on delete set null;
alter table public.order_returns
  add column if not exists admin_note text not null default '',
  add column if not exists decided_by uuid references auth.users(id) on delete set null,
  add column if not exists decided_at timestamptz;

create or replace function public.admin_list_orders(
  p_status text default null,
  p_search text default null
) returns table(
  id uuid,status text,total numeric,payment_method text,payment_status text,
  buyer_name text,shop_name text,item_count bigint,created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('orders.view') then
    raise exception 'You do not have permission to view orders.';
  end if;
  return query select o.id,o.status,o.total,o.payment_method,o.payment_status,
    coalesce(nullif(trim(b.full_name),''),'Tkoi buyer'),s.name,
    (select count(*) from public.order_items oi where oi.order_id=o.id),o.created_at
  from public.orders o join public.profiles b on b.id=o.buyer_id
  join public.shops s on s.id=o.shop_id
  where (p_status is null or o.status=p_status)
    and (p_search is null or trim(p_search)='' or s.name ilike '%'||trim(p_search)||'%'
      or b.full_name ilike '%'||trim(p_search)||'%'
      or o.id::text ilike trim(p_search)||'%')
  order by o.created_at desc limit 300;
end; $$;

create or replace function public.admin_get_order_detail(p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_result jsonb;
begin
  if not public.has_admin_permission('orders.view') then
    raise exception 'You do not have permission to view orders.';
  end if;
  select jsonb_build_object(
    'id',o.id,'status',o.status,'total',o.total,
    'payment_method',o.payment_method,'payment_status',o.payment_status,
    'payment_channel',o.payment_channel,
    'buyer_id',o.buyer_id,
    'buyer_name',coalesce(nullif(trim(b.full_name),''),'Tkoi buyer'),
    'seller_id',o.seller_id,'shop_id',o.shop_id,'shop_name',s.name,
    'delivery_address_masked','Hidden — reveal requires an audited reason',
    'created_at',o.created_at,'completed_at',o.completed_at,
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'id',oi.id,'product_id',oi.product_id,'product_name',oi.product_name,
      'quantity',oi.quantity,'unit_price',oi.unit_price,'image_url',oi.image_url
    ) order by oi.created_at) from public.order_items oi where oi.order_id=o.id),'[]'::jsonb)
  ) into v_result
  from public.orders o join public.profiles b on b.id=o.buyer_id
  join public.shops s on s.id=o.shop_id where o.id=p_order_id;
  if v_result is null then raise exception 'Order not found.'; end if;
  return v_result;
end; $$;

create or replace function public.admin_reveal_order_address(
  p_order_id uuid,p_reason text
) returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare v_order public.orders%rowtype;
begin
  if not public.has_admin_permission('orders.view') then
    raise exception 'You do not have permission to reveal shipping addresses.';
  end if;
  select * into v_order from public.orders where id=p_order_id;
  if v_order.id is null then raise exception 'Order not found.'; end if;
  if not public.admin_target_is_actionable(v_order.buyer_id) then
    raise exception 'You cannot reveal your own or another admin''s address.';
  end if;
  perform public.write_admin_audit(
    'order.reveal_address','order',p_order_id,null,
    jsonb_build_object('revealed',true),p_reason,null
  );
  return v_order.delivery_address;
end; $$;

create or replace function public.apply_return_status_transition(
  p_return_id uuid,p_status text,p_admin_override boolean default false
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_return public.order_returns%rowtype;
begin
  select * into v_return from public.order_returns where id=p_return_id for update;
  if v_return.id is null then raise exception 'Return request not found.'; end if;
  if not p_admin_override and v_return.seller_id<>auth.uid() then
    raise exception 'Return request not found.';
  end if;
  if p_status not in ('approved','rejected','received','resolved') then
    raise exception 'Invalid return status.';
  end if;
  if not p_admin_override and not (
    (v_return.status='requested' and p_status in ('approved','rejected')) or
    (v_return.status='approved' and p_status='received') or
    (v_return.status='received' and p_status='resolved')
  ) then raise exception 'That return status change is not allowed.'; end if;
  if p_admin_override and not (
    (v_return.status='requested' and p_status in ('approved','rejected','resolved')) or
    (v_return.status='approved' and p_status in ('received','resolved')) or
    (v_return.status='received' and p_status='resolved') or
    v_return.status=p_status
  ) then raise exception 'That admin return decision is not allowed.'; end if;
  if v_return.status=p_status then return; end if;
  update public.order_returns set status=p_status where id=p_return_id;
  -- Existing triggers perform review cleanup and seller-wallet reversal.
end; $$;

create or replace function public.update_return_status(
  p_return_id uuid,p_status text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.assert_account_allowed('commerce');
  perform public.apply_return_status_transition(p_return_id,p_status,false);
end; $$;

create or replace function public.admin_list_returns(p_status text default null)
returns table(
  id uuid,order_id uuid,status text,reason text,details text,admin_note text,
  buyer_id uuid,buyer_name text,seller_id uuid,shop_id uuid,shop_name text,
  order_total numeric,payment_method text,created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('returns.decide') then
    raise exception 'You do not have permission to view return requests.';
  end if;
  return query select r.id,r.order_id,r.status,r.reason,r.details,r.admin_note,
    r.buyer_id,coalesce(nullif(trim(p.full_name),''),'Tkoi buyer'),r.seller_id,
    r.shop_id,s.name,o.total,o.payment_method,r.created_at
  from public.order_returns r join public.orders o on o.id=r.order_id
  join public.profiles p on p.id=r.buyer_id join public.shops s on s.id=r.shop_id
  where p_status is null or r.status=p_status order by r.created_at desc;
end; $$;

create or replace function public.admin_decide_return(
  p_return_id uuid,p_status text,p_note text,p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_return public.order_returns%rowtype; v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('returns.decide') then
    raise exception 'You do not have permission to decide returns.';
  end if;
  select * into v_return from public.order_returns where id=p_return_id for update;
  if v_return.id is null then raise exception 'Return request not found.'; end if;
  if not public.admin_target_is_actionable(v_return.buyer_id)
     or not public.admin_target_is_actionable(v_return.seller_id) then
    raise exception 'You cannot decide a return involving yourself or another admin.';
  end if;
  if char_length(trim(coalesce(p_note,''))) not between 10 and 1000
     or coalesce(p_note,'')~'[<>]' then
    raise exception 'Enter a decision note of at least 10 characters.';
  end if;
  if v_return.status=p_status and v_return.admin_note=trim(p_note) then return; end if;
  v_before:=to_jsonb(v_return);
  perform public.apply_return_status_transition(p_return_id,p_status,true);
  update public.order_returns set admin_note=trim(p_note),decided_by=auth.uid(),
    decided_at=now() where id=p_return_id;
  select to_jsonb(r) into v_after from public.order_returns r where r.id=p_return_id;
  perform public.write_admin_audit(
    'return.'||p_status,'order_return',p_return_id,v_before,v_after,p_reason,null
  );
end; $$;

create or replace function public.process_withdrawal_internal(
  p_withdrawal_id uuid,p_action text,p_admin_note text,p_external_reference text,
  p_processed_by uuid
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_request public.withdrawal_requests%rowtype;
begin
  select * into v_request from public.withdrawal_requests
  where id=p_withdrawal_id for update;
  if v_request.id is null then raise exception 'Withdrawal request not found.'; end if;
  if p_action='approve' then
    if v_request.status='approved' then return; end if;
    if v_request.status<>'pending' then raise exception 'Only pending requests can be approved.'; end if;
    update public.withdrawal_requests set status='approved',
      admin_note=left(coalesce(p_admin_note,''),500),processed_by=p_processed_by
    where id=v_request.id;
  elsif p_action='paid' then
    if nullif(trim(coalesce(p_external_reference,'')),'') is null then
      raise exception 'A payment reference is required before marking a withdrawal paid.';
    end if;
    if v_request.status='paid' and v_request.external_reference=trim(p_external_reference) then return; end if;
    if v_request.status<>'approved' then raise exception 'Approve the request before marking it paid.'; end if;
    update public.withdrawal_requests set status='paid',processed_at=now(),
      processed_by=p_processed_by,admin_note=left(coalesce(p_admin_note,admin_note),500),
      external_reference=trim(p_external_reference) where id=v_request.id;
  elsif p_action='reject' then
    if v_request.status='rejected' then return; end if;
    if v_request.status not in ('pending','approved') then
      raise exception 'Only pending or approved requests can be rejected.';
    end if;
    update public.withdrawal_requests set status='rejected',processed_at=now(),
      processed_by=p_processed_by,admin_note=left(coalesce(p_admin_note,''),500),
      external_reference=nullif(trim(p_external_reference),'') where id=v_request.id;
    insert into public.seller_wallet_transactions(
      shop_id,seller_id,withdrawal_request_id,type,amount,status,note
    ) values(v_request.shop_id,v_request.seller_id,v_request.id,
      'withdrawal_reversal',v_request.amount,'available',
      'Rejected withdrawal returned to available balance.') on conflict do nothing;
  else raise exception 'Action must be approve, paid, or reject.';
  end if;
end; $$;

create or replace function public.admin_process_withdrawal(
  p_withdrawal_id uuid,p_action text,p_admin_note text default null,
  p_external_reference text default null
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.process_withdrawal_internal(
    p_withdrawal_id,p_action,p_admin_note,p_external_reference,null
  );
end; $$;

create or replace function public.admin_process_withdrawal_authenticated(
  p_withdrawal_id uuid,p_action text,p_admin_note text,
  p_external_reference text,p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_request public.withdrawal_requests%rowtype; v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('withdrawals.manage') then
    raise exception 'You do not have permission to process withdrawals.';
  end if;
  select * into v_request from public.withdrawal_requests where id=p_withdrawal_id for update;
  if v_request.id is null then raise exception 'Withdrawal request not found.'; end if;
  if not public.admin_target_is_actionable(v_request.seller_id) then
    raise exception 'You cannot process your own or another admin''s withdrawal.';
  end if;
  if char_length(trim(coalesce(p_admin_note,''))) not between 10 and 500 then
    raise exception 'Enter an admin note of at least 10 characters.';
  end if;
  v_before:=to_jsonb(v_request);
  perform public.process_withdrawal_internal(
    p_withdrawal_id,p_action,p_admin_note,p_external_reference,auth.uid()
  );
  select to_jsonb(w) into v_after from public.withdrawal_requests w where w.id=p_withdrawal_id;
  if v_before is distinct from v_after then
    perform public.write_admin_audit(
      'withdrawal.'||p_action,'withdrawal_request',p_withdrawal_id,
      v_before,v_after,p_reason,null
    );
  end if;
end; $$;

create or replace function public.admin_list_withdrawals(p_status text default null)
returns table(
  id uuid,shop_id uuid,shop_name text,seller_id uuid,seller_name text,
  amount numeric,payout_method text,masked_account text,status text,
  admin_note text,external_reference text,is_demo boolean,
  requested_at timestamptz,processed_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('withdrawals.view') then
    raise exception 'You do not have permission to view withdrawals.';
  end if;
  return query select w.id,w.shop_id,s.name,w.seller_id,
    coalesce(nullif(trim(p.full_name),''),'Tkoi seller'),w.amount,w.payout_method,
    case when char_length(w.account_number_snapshot)<=4 then '••••'
      else '•••• '||right(w.account_number_snapshot,4) end,
    w.status,w.admin_note,w.external_reference,w.is_demo,w.requested_at,w.processed_at
  from public.withdrawal_requests w join public.shops s on s.id=w.shop_id
  join public.profiles p on p.id=w.seller_id
  where p_status is null or w.status=p_status order by w.requested_at desc;
end; $$;

create or replace function public.admin_reveal_withdrawal_account(
  p_withdrawal_id uuid,p_reason text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_request public.withdrawal_requests%rowtype;
begin
  if not public.has_admin_permission('withdrawals.reveal') then
    raise exception 'You do not have permission to reveal payout details.';
  end if;
  select * into v_request from public.withdrawal_requests where id=p_withdrawal_id;
  if v_request.id is null then raise exception 'Withdrawal request not found.'; end if;
  if not public.admin_target_is_actionable(v_request.seller_id) then
    raise exception 'You cannot reveal your own or another admin''s payout details.';
  end if;
  perform public.write_admin_audit(
    'withdrawal.reveal_account','withdrawal_request',p_withdrawal_id,null,
    jsonb_build_object('revealed',true),p_reason,null
  );
  return jsonb_build_object(
    'method',v_request.payout_method,'account_name',v_request.account_name_snapshot,
    'account_number',v_request.account_number_snapshot,
    'bank_name',v_request.bank_name_snapshot
  );
end; $$;

create or replace function public.admin_list_wallets()
returns table(
  shop_id uuid,shop_name text,seller_id uuid,seller_name text,
  available_balance numeric,pending_balance numeric,total_earned numeric,
  total_withdrawn numeric
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('wallet.view') then
    raise exception 'You do not have permission to view seller wallets.';
  end if;
  return query
  select s.id,s.name,s.owner_id,coalesce(nullif(trim(p.full_name),''),'Tkoi seller'),
    coalesce(sum(t.amount) filter(where t.type in (
      'sale_released','refund_reversal','withdrawal','withdrawal_reversal','adjustment'
    ) and t.status<>'pending'),0)::numeric(12,2),
    coalesce(sum(t.amount) filter(where t.type='sale_pending' and not exists(
      select 1 from public.seller_wallet_transactions closed
      where closed.order_id=t.order_id and closed.type in ('sale_released','refund_reversal')
    )),0)::numeric(12,2),
    coalesce(sum(t.amount) filter(where t.type='sale_released'),0)::numeric(12,2),
    coalesce((select sum(w.amount) from public.withdrawal_requests w
      where w.shop_id=s.id and w.status='paid'),0)::numeric(12,2)
  from public.shops s join public.profiles p on p.id=s.owner_id
  left join public.seller_wallet_transactions t on t.shop_id=s.id
  group by s.id,s.name,s.owner_id,p.full_name order by s.name;
end; $$;

create or replace function public.admin_get_wallet_ledger(p_shop_id uuid)
returns table(
  id uuid,order_id uuid,withdrawal_request_id uuid,type text,amount numeric,
  status text,note text,created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('wallet.view') then
    raise exception 'You do not have permission to view seller wallets.';
  end if;
  return query select t.id,t.order_id,t.withdrawal_request_id,t.type,t.amount,
    t.status,t.note,t.created_at from public.seller_wallet_transactions t
    where t.shop_id=p_shop_id order by t.created_at desc;
end; $$;

create or replace function public.get_admin_marketplace_settings()
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_settings public.marketplace_settings%rowtype;
begin
  if not public.has_admin_permission('settings.view') then
    raise exception 'You do not have permission to view marketplace settings.';
  end if;
  select * into v_settings from public.marketplace_settings where singleton=true;
  return jsonb_build_object(
    'platform_fee_percent',v_settings.platform_fee_percent,
    'minimum_withdrawal',v_settings.minimum_withdrawal,
    'auto_release_days',v_settings.auto_release_days,
    'demo_mode',v_settings.demo_mode
  );
end; $$;

create or replace function public.admin_update_marketplace_settings(
  p_platform_fee_percent numeric,p_minimum_withdrawal numeric,
  p_auto_release_days integer,p_demo_mode boolean,p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('settings.edit') then
    raise exception 'Only a super admin can edit marketplace settings.';
  end if;
  if p_platform_fee_percent not between 0 and 30 then
    raise exception 'Platform fee must be between 0 and 30 percent.';
  end if;
  if p_minimum_withdrawal<1 or p_minimum_withdrawal>100000 then
    raise exception 'Minimum withdrawal must be between PHP 1 and PHP 100,000.';
  end if;
  if p_auto_release_days not between 1 and 90 then
    raise exception 'Auto-release days must be between 1 and 90.';
  end if;
  select to_jsonb(s) into v_before from public.marketplace_settings s
    where singleton=true for update;
  update public.marketplace_settings set
    platform_fee_percent=p_platform_fee_percent,
    minimum_withdrawal=p_minimum_withdrawal,
    auto_release_days=p_auto_release_days,
    demo_mode=p_demo_mode,demo_withdrawals_enabled=p_demo_mode,updated_at=now()
  where singleton=true;
  select to_jsonb(s) into v_after from public.marketplace_settings s where singleton=true;
  if v_before is distinct from v_after then
    perform public.write_admin_audit(
      'settings.update','marketplace_settings',null,v_before,v_after,p_reason,null
    );
  end if;
end; $$;

create or replace function public.request_demo_seller_withdrawal(
  p_shop_id uuid,p_amount numeric,p_payout_account_id uuid
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_request_id uuid;
begin
  perform public.assert_account_allowed('payout');
  if not coalesce((select demo_mode from public.marketplace_settings where singleton=true),false) then
    raise exception 'Demo mode is disabled.';
  end if;
  v_request_id:=public.request_seller_withdrawal(p_shop_id,p_amount,p_payout_account_id);
  update public.withdrawal_requests set status='paid',processed_at=now(),is_demo=true,
    admin_note='Demo withdrawal only. No real funds were transferred.',
    external_reference='DEMO-'||upper(left(v_request_id::text,8)) where id=v_request_id;
  return v_request_id;
end; $$;

create or replace function public.save_demo_seller_payout_account(
  p_shop_id uuid,p_account_id uuid,p_method text,p_account_name text,
  p_account_number text,p_bank_name text default null,p_is_default boolean default false
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
  perform public.assert_account_allowed('payout');
  if not coalesce((select demo_mode from public.marketplace_settings where singleton=true),false) then
    raise exception 'Demo mode is disabled.';
  end if;
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=v_user) then
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
  if p_is_default then update public.seller_payout_accounts set is_default=false
    where shop_id=p_shop_id and seller_id=v_user and is_default; end if;
  if p_account_id is null then
    insert into public.seller_payout_accounts(
      shop_id,seller_id,method,account_name,account_number,bank_name,is_default
    ) values(p_shop_id,v_user,p_method,trim(p_account_name),trim(p_account_number),
      case when p_method='bank' then trim(p_bank_name) else null end,
      p_is_default or not exists(select 1 from public.seller_payout_accounts
        where shop_id=p_shop_id and seller_id=v_user)) returning id into v_id;
  else
    update public.seller_payout_accounts set method=p_method,
      account_name=trim(p_account_name),account_number=trim(p_account_number),
      bank_name=case when p_method='bank' then trim(p_bank_name) else null end,
      is_default=p_is_default
    where id=p_account_id and shop_id=p_shop_id and seller_id=v_user returning id into v_id;
    if v_id is null then raise exception 'Payout account not found.'; end if;
  end if;
  return v_id;
end; $$;

create or replace function public.admin_list_audit_log(
  p_action text default null,p_admin_id uuid default null,p_target_type text default null
) returns table(
  id uuid,admin_id uuid,admin_name text,action text,target_type text,
  target_id uuid,reason text,ticket_id uuid,created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('audit.view') then
    raise exception 'You do not have permission to view the audit log.';
  end if;
  return query select a.id,a.admin_id,
    coalesce(nullif(trim(p.full_name),''),'Tkoi admin'),a.action,a.target_type,
    a.target_id,a.reason,a.ticket_id,a.created_at
  from public.admin_audit_log a left join public.profiles p on p.id=a.admin_id
  where (p_action is null or a.action ilike '%'||trim(p_action)||'%')
    and (p_admin_id is null or a.admin_id=p_admin_id)
    and (p_target_type is null or a.target_type=p_target_type)
  order by a.created_at desc limit 500;
end; $$;

revoke all on function public.apply_return_status_transition(uuid,text,boolean) from public,anon,authenticated;
revoke all on function public.process_withdrawal_internal(uuid,text,text,text,uuid) from public,anon,authenticated;
revoke all on function public.admin_list_orders(text,text) from public,anon;
revoke all on function public.admin_get_order_detail(uuid) from public,anon;
revoke all on function public.admin_reveal_order_address(uuid,text) from public,anon;
revoke all on function public.admin_list_returns(text) from public,anon;
revoke all on function public.admin_decide_return(uuid,text,text,text) from public,anon;
revoke all on function public.admin_process_withdrawal_authenticated(uuid,text,text,text,text) from public,anon;
revoke all on function public.admin_list_withdrawals(text) from public,anon;
revoke all on function public.admin_reveal_withdrawal_account(uuid,text) from public,anon;
revoke all on function public.admin_list_wallets() from public,anon;
revoke all on function public.admin_get_wallet_ledger(uuid) from public,anon;
revoke all on function public.get_admin_marketplace_settings() from public,anon;
revoke all on function public.admin_update_marketplace_settings(numeric,numeric,integer,boolean,text) from public,anon;
revoke all on function public.admin_list_audit_log(text,uuid,text) from public,anon;
grant execute on function public.admin_list_orders(text,text) to authenticated;
grant execute on function public.admin_get_order_detail(uuid) to authenticated;
grant execute on function public.admin_reveal_order_address(uuid,text) to authenticated;
grant execute on function public.admin_list_returns(text) to authenticated;
grant execute on function public.admin_decide_return(uuid,text,text,text) to authenticated;
grant execute on function public.admin_process_withdrawal_authenticated(uuid,text,text,text,text) to authenticated;
grant execute on function public.admin_list_withdrawals(text) to authenticated;
grant execute on function public.admin_reveal_withdrawal_account(uuid,text) to authenticated;
grant execute on function public.admin_list_wallets() to authenticated;
grant execute on function public.admin_get_wallet_ledger(uuid) to authenticated;
grant execute on function public.get_admin_marketplace_settings() to authenticated;
grant execute on function public.admin_update_marketplace_settings(numeric,numeric,integer,boolean,text) to authenticated;
grant execute on function public.admin_list_audit_log(text,uuid,text) to authenticated;

notify pgrst,'reload schema';
