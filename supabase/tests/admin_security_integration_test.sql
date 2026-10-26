-- Run only against an isolated Supabase development database after migrations
-- 01 through 16. All test users and records are rolled back at the end.
begin;

create or replace function pg_temp.expect_error(p_sql text,p_fragment text)
returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception '__unexpected_success__';
exception when others then
  if sqlerrm='__unexpected_success__' then raise; end if;
  if sqlerrm not ilike '%'||p_fragment||'%' then
    raise exception 'Expected error containing "%", got "%".',p_fragment,sqlerrm;
  end if;
end; $$;

-- Stable UUIDs make failures easy to inspect while the transaction is open.
insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('a0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','admin-security-super@example.test','',now(),
 '+639170001001',now(),'{}','{}',now(),now()),
('a0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','admin-security-finance@example.test','',now(),
 '+639170001002',now(),'{}','{}',now(),now()),
('a0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','admin-security-user@example.test','',now(),
 '+639170001003',now(),'{}','{}',now(),now()),
('a0000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','admin-security-seller@example.test','',now(),
 '+639170001004',now(),'{}','{}',now(),now()),
('a0000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','admin-security-buyer@example.test','',now(),
 '+639170001005',now(),'{}','{}',now(),now());

insert into public.profiles(id,full_name,username,email,mobile_number,address)
values
('a0000000-0000-0000-0000-000000000001','Security Super','security_super_test','admin-security-super@example.test','09170001001','Test address'),
('a0000000-0000-0000-0000-000000000002','Security Finance','security_finance_test','admin-security-finance@example.test','09170001002','Test address'),
('a0000000-0000-0000-0000-000000000003','Security User','security_user_test','admin-security-user@example.test','09170001003','Test address'),
('a0000000-0000-0000-0000-000000000004','Security Seller','security_seller_test','admin-security-seller@example.test','09170001004','Test address'),
('a0000000-0000-0000-0000-000000000005','Security Buyer','security_buyer_test','admin-security-buyer@example.test','09170001005','Test address')
on conflict(id) do update set full_name=excluded.full_name;

insert into public.user_roles(user_id,role,granted_by) values
('a0000000-0000-0000-0000-000000000001','super_admin','a0000000-0000-0000-0000-000000000001'),
('a0000000-0000-0000-0000-000000000002','finance','a0000000-0000-0000-0000-000000000001');

insert into public.shops(
  id,owner_id,name,owner_name,description,contact_number,email,location
) values(
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004',
  'Security Test Shop','Security Seller','Integration test shop',
  '09170001004','admin-security-seller@example.test','Test City'
);

insert into public.products(
  id,shop_id,seller_id,name,species,category,description,price,quantity,size,
  age_months,sex,health_condition,seller_location,status
) values(
  'c0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004',
  'Security Test Fish','Test species','Other','Test listing',100,2,'Small',
  2,'Unknown','Healthy','Test City','available'
);

insert into public.conversations(id,buyer_id,seller_id) values(
  'd0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000005',
  'a0000000-0000-0000-0000-000000000004'
);
insert into public.messages(id,conversation_id,sender_id,body) values(
  'd1000000-0000-0000-0000-000000000001',
  'd0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000005','Private test message'
);

insert into public.support_tickets(
  id,user_id,category,subject,status,related_conversation_id
) values
('e0000000-0000-0000-0000-000000000001',
 'a0000000-0000-0000-0000-000000000005','other','Unlinked ticket','open',null),
('e0000000-0000-0000-0000-000000000002',
 'a0000000-0000-0000-0000-000000000005','other','Linked chat ticket','open',
 'd0000000-0000-0000-0000-000000000001');
insert into public.ticket_messages(
  ticket_id,sender_id,sender_type,body,is_internal_note
) values
('e0000000-0000-0000-0000-000000000002',
 'a0000000-0000-0000-0000-000000000005','user','Visible customer message',false),
('e0000000-0000-0000-0000-000000000002',
 'a0000000-0000-0000-0000-000000000001','agent','Private internal note',true);

-- A normal authenticated user is rejected by every client-facing admin RPC.
set local role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003',true);
select pg_temp.expect_error('select * from public.get_admin_team()','permission');
select pg_temp.expect_error('select public.admin_target_is_actionable(null::uuid)','permission');
select pg_temp.expect_error('select * from public.admin_list_users(null,null,null,null)','permission');
select pg_temp.expect_error('select public.admin_get_user_detail(null::uuid)','permission');
select pg_temp.expect_error('select public.admin_reveal_user_contact(null::uuid,''Valid audit reason'')','permission');
select pg_temp.expect_error('select public.admin_set_account_control(null::uuid,''active'',null,''Public reason text'',''Internal reason text'',''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_list_tickets(null,null,null,false)','permission');
select pg_temp.expect_error('select public.admin_get_ticket_detail(null::uuid)','permission');
select pg_temp.expect_error('select public.admin_update_ticket(null::uuid,''open'',''normal'',null,''Valid audit reason'')','permission');
select pg_temp.expect_error('select public.admin_reply_ticket(null::uuid,''reply'',false,''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_list_reports(null,null)','permission');
select pg_temp.expect_error('select public.admin_resolve_report(null::uuid,''dismissed'',''Resolution note text'',''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_view_ticket_conversation(null::uuid,''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_list_moderation_content(''product'',null,null)','permission');
select pg_temp.expect_error('select public.admin_set_content_moderation(''product'',null::uuid,''removed'',''Valid moderation reason'',null,null)','permission');
select pg_temp.expect_error('select * from public.admin_list_orders(null,null)','permission');
select pg_temp.expect_error('select public.admin_get_order_detail(null::uuid)','permission');
select pg_temp.expect_error('select public.admin_reveal_order_address(null::uuid,''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_list_returns(null)','permission');
select pg_temp.expect_error('select public.admin_decide_return(null::uuid,''rejected'',''Valid decision note'',''Valid audit reason'')','permission');
select pg_temp.expect_error('select public.admin_process_withdrawal_authenticated(null::uuid,''reject'',''Valid admin note'',null,''Valid audit reason'')','permission');
select pg_temp.expect_error('select public.admin_process_withdrawal(null::uuid,''reject'',null,null)','permission');
select pg_temp.expect_error('select * from public.admin_list_withdrawals(null)','permission');
select pg_temp.expect_error('select public.admin_reveal_withdrawal_account(null::uuid,''Valid audit reason'')','permission');
select pg_temp.expect_error('select * from public.admin_list_wallets()','permission');
select pg_temp.expect_error('select * from public.admin_get_wallet_ledger(null::uuid)','permission');
select pg_temp.expect_error('select public.get_admin_marketplace_settings()','permission');
select pg_temp.expect_error('select public.admin_update_marketplace_settings(5,100,7,true,''Valid audit reason'')','super admin');
select pg_temp.expect_error('select * from public.admin_list_audit_log(null,null,null)','permission');
select pg_temp.expect_error('select public.get_admin_dashboard_stats()','Admin access');

-- Direct role writes are not available to app users (self-promotion fails).
select pg_temp.expect_error(
  'insert into public.user_roles(user_id,role) values(''a0000000-0000-0000-0000-000000000003'',''super_admin'')',
  'permission'
);

-- A seller cannot alter protected moderation fields.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000004',true);
select pg_temp.expect_error(
  'update public.products set moderation_status=''removed'' where id=''c0000000-0000-0000-0000-000000000001''',
  'authorized admin'
);

-- Users never receive internal notes from the user RPC.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000005',true);
do $$
begin
  if (select count(*) from public.get_my_support_ticket_messages(
      'e0000000-0000-0000-0000-000000000002'))<>1 then
    raise exception 'Internal ticket notes leaked to the user.';
  end if;
end $$;

-- Super admins cannot moderate themselves or another admin.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error(
  'select public.admin_set_account_control(''a0000000-0000-0000-0000-000000000001'',''banned'',null,''Public reason text'',''Internal reason text'',''Valid audit reason'')',
  'yourself or another admin'
);
select pg_temp.expect_error(
  'select public.admin_set_account_control(''a0000000-0000-0000-0000-000000000002'',''suspended'',now()+interval ''1 day'',''Public reason text'',''Internal reason text'',''Valid audit reason'')',
  'yourself or another admin'
);

-- Chat reading requires a linked, open ticket and always produces an audit row.
select pg_temp.expect_error(
  'select * from public.admin_view_ticket_conversation(''e0000000-0000-0000-0000-000000000001'',''Investigating customer complaint'')',
  'not linked'
);
do $$
begin
  if (select count(*) from public.admin_view_ticket_conversation(
      'e0000000-0000-0000-0000-000000000002',
      'Investigating customer complaint'))<>1 then
    raise exception 'Linked ticket did not return its conversation.';
  end if;
  if not exists(select 1 from public.admin_audit_log
    where action='chat.view_via_ticket'
      and ticket_id='e0000000-0000-0000-0000-000000000002') then
    raise exception 'Chat access did not create an audit entry.';
  end if;
end $$;

-- Account moderation writes history/audit records in the same transaction.
select public.admin_set_account_control(
  'a0000000-0000-0000-0000-000000000003','suspended',now()+interval '1 day',
  'Temporarily restricted for testing','Internal integration test reason',
  'Testing account suspension auditing'
);
reset role;

do $$
declare v_category text;
begin
  foreach v_category in array array[
    'commerce','listing','chat','review','favorite','payout','profile','appeal'
  ] loop
    if public.is_account_action_allowed(
      v_category,'a0000000-0000-0000-0000-000000000003'
    ) then raise exception 'Suspension incorrectly allowed category %.',v_category; end if;
  end loop;
  if not public.is_account_action_allowed(
      'existing_order_completion','a0000000-0000-0000-0000-000000000003')
     or not public.is_account_action_allowed(
      'support','a0000000-0000-0000-0000-000000000003') then
    raise exception 'Suspension blocked an allowed completion/support action.';
  end if;
  if not exists(select 1 from public.account_status_history
      where user_id='a0000000-0000-0000-0000-000000000003'
        and status='suspended')
     or not exists(select 1 from public.admin_audit_log
      where target_id='a0000000-0000-0000-0000-000000000003'
        and action='user.suspended') then
    raise exception 'Account moderation history or audit entry is missing.';
  end if;
end $$;

select pg_temp.expect_error(
  'update public.admin_audit_log set reason=''Changed audit reason'' where target_id=''a0000000-0000-0000-0000-000000000003''',
  'immutable'
);

update public.account_controls set status='banned',suspended_until=null
where user_id='a0000000-0000-0000-0000-000000000003';
do $$
declare v_category text;
begin
  foreach v_category in array array[
    'commerce','listing','chat','review','favorite','payout','profile',
    'existing_order_completion','support'
  ] loop
    if public.is_account_action_allowed(
      v_category,'a0000000-0000-0000-0000-000000000003'
    ) then raise exception 'Ban incorrectly allowed category %.',v_category; end if;
  end loop;
  if not public.is_account_action_allowed(
      'appeal','a0000000-0000-0000-0000-000000000003') then
    raise exception 'Ban blocked the appeal category.';
  end if;
end $$;

-- Finance processing reuses the existing immutable ledger reversal logic.
insert into public.seller_payout_accounts(
  id,shop_id,seller_id,method,account_name,account_number,is_default
) values(
  'f0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004','gcash','Security Seller',
  '09170001004',true
);
insert into public.withdrawal_requests(
  id,shop_id,seller_id,payout_account_id,amount,payout_method,
  account_name_snapshot,account_number_snapshot,status
) values(
  'f1000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004',
  'f0000000-0000-0000-0000-000000000001',100,'gcash','Security Seller',
  '09170001004','pending'
);
insert into public.seller_wallet_transactions(
  shop_id,seller_id,withdrawal_request_id,type,amount,status,note
) values(
  'b0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000004',
  'f1000000-0000-0000-0000-000000000001','withdrawal',-100,'reserved',
  'Admin integration test withdrawal'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
select public.admin_process_withdrawal_authenticated(
  'f1000000-0000-0000-0000-000000000001','reject',
  'Rejected during integration testing',null,'Testing wallet reversal safely'
);
reset role;

do $$
begin
  if not exists(select 1 from public.withdrawal_requests
      where id='f1000000-0000-0000-0000-000000000001'
        and status='rejected' and processed_by='a0000000-0000-0000-0000-000000000002') then
    raise exception 'Finance rejection was not recorded.';
  end if;
  if not exists(select 1 from public.seller_wallet_transactions
      where withdrawal_request_id='f1000000-0000-0000-0000-000000000001'
        and type='withdrawal_reversal' and amount=100) then
    raise exception 'Withdrawal rejection did not append a wallet reversal.';
  end if;
end $$;

rollback;
