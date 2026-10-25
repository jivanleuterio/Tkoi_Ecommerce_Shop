-- Run only against an isolated Supabase development database after migrations
-- 01 through 07. Everything is rolled back, including the test Auth users.
begin;

do $$
declare
  v_buyer uuid:=gen_random_uuid();
  v_seller uuid:=gen_random_uuid();
  v_shop uuid:=gen_random_uuid();
  v_payment uuid:=gen_random_uuid();
  v_order uuid:=gen_random_uuid();
  v_payment2 uuid:=gen_random_uuid();
  v_order2 uuid:=gen_random_uuid();
  v_account uuid;
  v_withdrawal uuid;
  v_value numeric;
begin
  insert into auth.users(
    id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
    phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,
    created_at,updated_at
  ) values
    (v_buyer,'00000000-0000-0000-0000-000000000000','authenticated',
      'authenticated','wallet-buyer@example.test','',now(),'+639170000001',now(),
      '{}'::jsonb,'{}'::jsonb,now(),now()),
    (v_seller,'00000000-0000-0000-0000-000000000000','authenticated',
      'authenticated','wallet-seller@example.test','',now(),'+639170000002',now(),
      '{}'::jsonb,'{}'::jsonb,now(),now());
  insert into public.profiles(id,full_name,username,email,mobile_number,address)
  values
    (v_buyer,'Wallet Buyer','wallet_buyer_test','wallet-buyer@example.test','09170000001','Test buyer address'),
    (v_seller,'Wallet Seller','wallet_seller_test','wallet-seller@example.test','09170000002','Test seller address')
  on conflict(id) do update set full_name=excluded.full_name,
    username=excluded.username,email=excluded.email,
    mobile_number=excluded.mobile_number,address=excluded.address;
  insert into public.shops(id,owner_id,name,owner_name,description,contact_number,email,location)
  values(v_shop,v_seller,'Wallet Test Shop','Wallet Seller','Test shop','09170000002',
    'wallet-seller@example.test','Test City');
  insert into public.payment_transactions(id,buyer_id,amount,status,payment_channel)
  values(v_payment,v_buyer,1000,'pending','GCASH');
  insert into public.orders(
    id,buyer_id,seller_id,shop_id,total,delivery_address,payment_method,
    payment_status,payment_transaction_id,payment_channel
  ) values(
    v_order,v_buyer,v_seller,v_shop,1000,'Test delivery address',
    'Xendit','pending',v_payment,'GCASH'
  );

  update public.orders set payment_status='paid' where id=v_order;
  select amount into v_value from public.seller_wallet_transactions
  where order_id=v_order and type='sale_pending';
  if v_value<>950 then raise exception 'Expected PHP 950 pending net, got %.',v_value; end if;
  select amount into v_value from public.seller_wallet_transactions
  where order_id=v_order and type='platform_fee';
  if v_value<>-50 then raise exception 'Expected PHP -50 fee, got %.',v_value; end if;

  update public.orders set status='confirmed' where id=v_order;
  update public.orders set status='preparing' where id=v_order;
  update public.orders set status='ready_for_delivery' where id=v_order;
  update public.orders set status='shipped' where id=v_order;
  perform set_config('request.jwt.claim.sub',v_buyer::text,true);
  perform public.mark_order_received(v_order);
  if not exists(select 1 from public.seller_wallet_transactions
    where order_id=v_order and type='sale_released' and amount=950) then
    raise exception 'Buyer confirmation did not release escrow.';
  end if;

  perform set_config('request.jwt.claim.sub',v_seller::text,true);
  v_account:=public.save_seller_payout_account(
    v_shop,null,'gcash','Wallet Seller','09170000002',null,true
  );
  v_withdrawal:=public.request_demo_seller_withdrawal(v_shop,100,v_account);
  if not exists(select 1 from public.withdrawal_requests
    where id=v_withdrawal and status='paid' and is_demo) then
    raise exception 'Demo withdrawal was not recorded as demo-paid.';
  end if;
  select available_balance into v_value
  from public.get_seller_wallet_summary(v_shop);
  if v_value<>850 then
    raise exception 'Expected PHP 850 after demo withdrawal, got %.',v_value;
  end if;
  perform public.reverse_order_earnings(v_order);

  select available_balance into v_value
  from public.get_seller_wallet_summary(v_shop);
  if v_value<>-100 then raise exception 'Expected PHP -100 balance, got %.',v_value; end if;
  begin
    perform public.request_seller_withdrawal(v_shop,100,v_account);
    raise exception 'Negative balance withdrawal was not blocked.';
  exception when others then
    if sqlerrm not ilike '%negative%' then raise; end if;
  end;

  -- Repeating append operations must not duplicate order ledger events.
  perform public.record_xendit_sale_pending(v_order);
  perform public.release_order_escrow(v_order);
  perform public.reverse_order_earnings(v_order);
  if (select count(*) from public.seller_wallet_transactions
      where order_id=v_order and type='sale_pending')<>1 then
    raise exception 'Pending sale idempotency failed.';
  end if;
  if (select count(*) from public.seller_wallet_transactions
      where order_id=v_order and type='sale_released')<>1 then
    raise exception 'Escrow release idempotency failed.';
  end if;
  if (select count(*) from public.seller_wallet_transactions
      where order_id=v_order and type='refund_reversal')<>1 then
    raise exception 'Refund reversal idempotency failed.';
  end if;

  insert into public.payment_transactions(id,buyer_id,amount,status,payment_channel)
  values(v_payment2,v_buyer,500,'pending','GCASH');
  insert into public.orders(
    id,buyer_id,seller_id,shop_id,total,delivery_address,payment_method,
    payment_status,payment_transaction_id,payment_channel
  ) values(
    v_order2,v_buyer,v_seller,v_shop,500,'Test delivery address',
    'Xendit','pending',v_payment2,'GCASH'
  );
  update public.orders set payment_status='paid' where id=v_order2;
  update public.orders set status='confirmed' where id=v_order2;
  update public.orders set status='preparing' where id=v_order2;
  update public.orders set status='ready_for_delivery' where id=v_order2;
  update public.orders set status='shipped' where id=v_order2;
  update public.orders set shipped_at=now()-interval '8 days' where id=v_order2;
  insert into public.order_returns(
    order_id,buyer_id,seller_id,shop_id,reason,details,status
  ) values(v_order2,v_buyer,v_seller,v_shop,'Other','Active test return','requested');
  perform public.release_due_seller_escrows();
  if exists(select 1 from public.seller_wallet_transactions
    where order_id=v_order2 and type='sale_released') then
    raise exception 'Auto-release ignored an active return hold.';
  end if;
  update public.order_returns set status='rejected' where order_id=v_order2;
  perform public.release_due_seller_escrows();
  if not exists(select 1 from public.seller_wallet_transactions
    where order_id=v_order2 and type='sale_released') then
    raise exception 'Escrow did not release after return rejection.';
  end if;
end $$;

rollback;
