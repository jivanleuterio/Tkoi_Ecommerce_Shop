-- Tkoi account moderation and immediate account-status enforcement.
-- Run after 11_admin_foundation.sql. Additive and safe to run twice.

create table if not exists public.account_controls (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active','suspended','banned')),
  suspended_until timestamptz,
  reason_public text not null default '' check (
    char_length(reason_public)<=500 and reason_public !~ '[<>]'
  ),
  reason_internal text not null default '' check (
    char_length(reason_internal)<=1000 and reason_internal !~ '[<>]'
  ),
  set_by uuid references auth.users(id) on delete set null,
  set_at timestamptz not null default now(),
  constraint account_controls_suspension_time check (
    status<>'suspended' or suspended_until is null or suspended_until>set_at
  )
);

create table if not exists public.account_status_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('active','suspended','banned')),
  suspended_until timestamptz,
  reason_public text not null default '',
  reason_internal text not null default '',
  set_by uuid not null references auth.users(id) on delete restrict,
  set_at timestamptz not null default now()
);

create index if not exists account_controls_status_idx
  on public.account_controls(status,suspended_until);
create index if not exists account_status_history_user_idx
  on public.account_status_history(user_id,set_at desc);

alter table public.account_controls enable row level security;
alter table public.account_status_history enable row level security;
revoke all on table public.account_controls from anon,authenticated;
revoke all on table public.account_status_history from anon,authenticated;

-- Some existing Tkoi databases were created before the phone-verification
-- helper was added to migration 06/security_hardening.sql. Define the same
-- server-side helper here so this migration never depends on that history.
create or replace function public.is_phone_verified(
  target_user uuid default auth.uid()
) returns boolean language sql stable security definer
set search_path=public,auth,pg_temp as $$
  select exists(
    select 1 from auth.users u
    where u.id=target_user
      and u.phone is not null
      and u.phone_confirmed_at is not null
  );
$$;
revoke all on function public.is_phone_verified(uuid) from public,anon;
grant execute on function public.is_phone_verified(uuid) to authenticated;

create or replace function public.get_account_status(p_user_id uuid)
returns text language sql stable security definer
set search_path=public,pg_temp as $$
  select case
    when c.status='suspended' and c.suspended_until is not null
      and c.suspended_until<=now() then 'active'
    else coalesce(c.status,'active')
  end
  from (select p_user_id id) requested
  left join public.account_controls c on c.user_id=requested.id;
$$;

create or replace function public.is_account_action_allowed(
  p_action_category text,
  p_user_id uuid default auth.uid()
) returns boolean language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare v_status text;
begin
  if p_user_id is null then return true; end if;
  v_status:=public.get_account_status(p_user_id);
  if v_status='active' then return true; end if;
  if v_status='suspended' then
    return p_action_category in ('existing_order_completion','support');
  end if;
  if v_status='banned' then return p_action_category='appeal'; end if;
  return false;
end; $$;

create or replace function public.assert_account_allowed(
  p_action_category text
) returns void language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare v_status text;
begin
  if auth.uid() is null then return; end if;
  v_status:=public.get_account_status(auth.uid());
  if public.is_account_action_allowed(p_action_category,auth.uid()) then return; end if;
  if v_status='suspended' then
    raise exception 'Your account is suspended. You can only finish eligible existing orders and use Help & Support.';
  end if;
  raise exception 'Your account is banned. You can only submit an appeal.';
end; $$;

create or replace function public.account_can_read(p_user_id uuid default auth.uid())
returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
  select p_user_id is null or public.get_account_status(p_user_id)<>'banned';
$$;

create or replace function public.enforce_actor_account_action()
returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
begin
  if auth.uid() is not null then
    -- Buyer-side order completion/cancellation RPCs legitimately restore a
    -- seller's product stock. That inventory write is not a buyer listing
    -- edit; RLS still prevents a buyer from directly editing the product.
    -- NEW is a polymorphic trigger record. Do not reference seller_id in the
    -- same boolean expression as TG_TABLE_NAME: PostgreSQL may evaluate the
    -- field access for tables such as messages that do not have seller_id.
    if tg_table_name='products' and tg_op='UPDATE' then
      if new.seller_id<>auth.uid() then
        return new;
      end if;
    end if;
    perform public.assert_account_allowed(tg_argv[0]);
  end if;
  if tg_op='DELETE' then
    return old;
  end if;
  return new;
end; $$;

create or replace function public.enforce_order_account_action()
returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op='INSERT' then
    perform public.assert_account_allowed('commerce');
  elsif new.status is distinct from old.status
    and new.status in ('completed','cancelled') then
    perform public.assert_account_allowed('existing_order_completion');
  else
    perform public.assert_account_allowed('commerce');
  end if;
  return new;
end; $$;

create or replace function public.enforce_return_account_action()
returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op='INSERT' or (old.buyer_id=auth.uid() and new.status='cancelled') then
    perform public.assert_account_allowed('existing_order_completion');
  else
    perform public.assert_account_allowed('commerce');
  end if;
  return new;
end; $$;

-- Ledger rows can also be appended while a buyer completes an existing order
-- or while an admin resolves a dispute. Only enforce the payout restriction
-- when the authenticated actor is the seller whose wallet is being changed.
create or replace function public.enforce_wallet_account_action()
returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
begin
  if auth.uid() is not null and auth.uid()=new.seller_id then
    perform public.assert_account_allowed('payout');
  end if;
  return new;
end; $$;

drop trigger if exists profiles_account_action on public.profiles;
create trigger profiles_account_action before update on public.profiles
for each row execute function public.enforce_actor_account_action('profile');
drop trigger if exists shops_account_action on public.shops;
create trigger shops_account_action before insert or update or delete on public.shops
for each row execute function public.enforce_actor_account_action('listing');
drop trigger if exists products_account_action on public.products;
create trigger products_account_action before insert or update or delete on public.products
for each row execute function public.enforce_actor_account_action('listing');
drop trigger if exists product_images_account_action on public.product_images;
create trigger product_images_account_action before insert or update or delete on public.product_images
for each row execute function public.enforce_actor_account_action('listing');
drop trigger if exists cart_items_account_action on public.cart_items;
create trigger cart_items_account_action before insert or update or delete on public.cart_items
for each row execute function public.enforce_actor_account_action('commerce');
drop trigger if exists payment_transactions_account_action on public.payment_transactions;
create trigger payment_transactions_account_action before insert or update or delete on public.payment_transactions
for each row execute function public.enforce_actor_account_action('commerce');
drop trigger if exists orders_account_action on public.orders;
create trigger orders_account_action before insert or update on public.orders
for each row execute function public.enforce_order_account_action();
drop trigger if exists product_favorites_account_action on public.product_favorites;
create trigger product_favorites_account_action before insert or delete on public.product_favorites
for each row execute function public.enforce_actor_account_action('favorite');
drop trigger if exists product_reviews_account_action on public.product_reviews;
create trigger product_reviews_account_action before insert or update or delete on public.product_reviews
for each row execute function public.enforce_actor_account_action('review');
drop trigger if exists review_images_account_action on public.review_images;
create trigger review_images_account_action before insert or update or delete on public.review_images
for each row execute function public.enforce_actor_account_action('review');
drop trigger if exists order_reviews_account_action on public.order_reviews;
create trigger order_reviews_account_action before insert or update or delete on public.order_reviews
for each row execute function public.enforce_actor_account_action('review');
drop trigger if exists order_returns_account_action on public.order_returns;
create trigger order_returns_account_action before insert or update on public.order_returns
for each row execute function public.enforce_return_account_action();
drop trigger if exists conversations_account_action on public.conversations;
create trigger conversations_account_action before insert or update or delete on public.conversations
for each row execute function public.enforce_actor_account_action('chat');
drop trigger if exists messages_account_action on public.messages;
create trigger messages_account_action before insert or update or delete on public.messages
for each row execute function public.enforce_actor_account_action('chat');
drop trigger if exists seller_payout_accounts_account_action on public.seller_payout_accounts;
create trigger seller_payout_accounts_account_action before insert or update or delete on public.seller_payout_accounts
for each row execute function public.enforce_actor_account_action('payout');
drop trigger if exists withdrawal_requests_account_action on public.withdrawal_requests;
create trigger withdrawal_requests_account_action before insert or update or delete on public.withdrawal_requests
for each row execute function public.enforce_actor_account_action('payout');
drop trigger if exists seller_wallet_transactions_account_action on public.seller_wallet_transactions;
create trigger seller_wallet_transactions_account_action before insert on public.seller_wallet_transactions
for each row execute function public.enforce_wallet_account_action();

-- Read policies: suspended users remain able to read their existing data;
-- banned users only receive the restricted access context and appeal RPCs.
drop policy if exists "Users view own profile" on public.profiles;
create policy "Users view own profile" on public.profiles for select to authenticated
using (id=auth.uid() and public.account_can_read(auth.uid()));
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated
using (id=auth.uid() and public.is_account_action_allowed('profile',auth.uid()))
with check (id=auth.uid() and public.is_account_action_allowed('profile',auth.uid()));

drop policy if exists "Anyone views shops" on public.shops;
create policy "Anyone views shops" on public.shops for select
using (auth.uid() is null or public.account_can_read(auth.uid()));
drop policy if exists "Public views active products and sellers view own" on public.products;
create policy "Public views active products and sellers view own" on public.products
for select using (
  (auth.uid() is null or public.account_can_read(auth.uid())) and (
    (status='available' and quantity>0) or seller_id=auth.uid()
    or public.is_product_in_my_cart(id)
  )
);
drop policy if exists "Users view images for visible products" on public.product_images;
create policy "Users view images for visible products" on public.product_images
for select using (
  (auth.uid() is null or public.account_can_read(auth.uid())) and exists(
    select 1 from public.products p where p.id=product_id
  )
);
drop policy if exists "Buyers view own cart" on public.cart_items;
create policy "Buyers view own cart" on public.cart_items for select to authenticated
using (buyer_id=auth.uid() and public.account_can_read(auth.uid()));
drop policy if exists "Buyers view own payment transactions" on public.payment_transactions;
create policy "Buyers view own payment transactions" on public.payment_transactions
for select to authenticated using (
  buyer_id=auth.uid() and public.account_can_read(auth.uid())
);
drop policy if exists "Buyers and sellers view related orders" on public.orders;
create policy "Buyers and sellers view related orders" on public.orders
for select to authenticated using (
  (buyer_id=auth.uid() or seller_id=auth.uid()) and public.account_can_read(auth.uid())
);
drop policy if exists "Buyers and sellers view related order items" on public.order_items;
create policy "Buyers and sellers view related order items" on public.order_items
for select to authenticated using (
  public.account_can_read(auth.uid()) and exists(
    select 1 from public.orders o where o.id=order_id
      and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())
  )
);
drop policy if exists "Users view own favorites" on public.product_favorites;
create policy "Users view own favorites" on public.product_favorites
for select to authenticated using (
  buyer_id=auth.uid() and public.account_can_read(auth.uid())
);
drop policy if exists "Authenticated users read product reviews" on public.product_reviews;
create policy "Authenticated users read product reviews" on public.product_reviews
for select to authenticated using (public.account_can_read(auth.uid()));
drop policy if exists "Authenticated users read review images" on public.review_images;
create policy "Authenticated users read review images" on public.review_images
for select to authenticated using (public.account_can_read(auth.uid()));
drop policy if exists "Order parties view reviews" on public.order_reviews;
create policy "Order parties view reviews" on public.order_reviews
for select to authenticated using (
  (buyer_id=auth.uid() or seller_id=auth.uid()) and public.account_can_read(auth.uid())
);
drop policy if exists "Order parties view returns" on public.order_returns;
create policy "Order parties view returns" on public.order_returns
for select to authenticated using (
  (buyer_id=auth.uid() or seller_id=auth.uid()) and public.account_can_read(auth.uid())
);
drop policy if exists "Participants view conversations" on public.conversations;
create policy "Participants view conversations" on public.conversations
for select to authenticated using (
  (buyer_id=auth.uid() or seller_id=auth.uid()) and public.account_can_read(auth.uid())
);
drop policy if exists "Participants view messages" on public.messages;
create policy "Participants view messages" on public.messages
for select to authenticated using (
  public.account_can_read(auth.uid()) and exists(
    select 1 from public.conversations c where c.id=conversation_id
      and (c.buyer_id=auth.uid() or c.seller_id=auth.uid())
  )
);
drop policy if exists "Sellers view own wallet ledger" on public.seller_wallet_transactions;
create policy "Sellers view own wallet ledger" on public.seller_wallet_transactions
for select to authenticated using (
  seller_id=auth.uid() and public.account_can_read(auth.uid())
);
drop policy if exists "Sellers view own payout accounts" on public.seller_payout_accounts;
create policy "Sellers view own payout accounts" on public.seller_payout_accounts
for select to authenticated using (
  seller_id=auth.uid() and public.account_can_read(auth.uid())
);
drop policy if exists "Sellers view own withdrawals" on public.withdrawal_requests;
create policy "Sellers view own withdrawals" on public.withdrawal_requests
for select to authenticated using (
  seller_id=auth.uid() and public.account_can_read(auth.uid())
);

-- Storage writes receive the same server-side status checks.
drop policy if exists "Users upload profile pictures" on storage.objects;
create policy "Users upload profile pictures" on storage.objects for insert to authenticated
with check (
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
  and public.is_account_action_allowed('profile',auth.uid())
);
drop policy if exists "Users update profile pictures" on storage.objects;
create policy "Users update profile pictures" on storage.objects for update to authenticated
using (bucket_id='profile-pictures' and owner_id=auth.uid()::text
  and public.is_account_action_allowed('profile',auth.uid()));
drop policy if exists "Users delete profile pictures" on storage.objects;
create policy "Users delete profile pictures" on storage.objects for delete to authenticated
using (bucket_id='profile-pictures' and owner_id=auth.uid()::text
  and public.is_account_action_allowed('profile',auth.uid()));
drop policy if exists "Verified sellers upload images" on storage.objects;
create policy "Verified sellers upload images" on storage.objects for insert to authenticated
with check (
  bucket_id in ('shop-logos','product-images')
  and (storage.foldername(name))[1]=auth.uid()::text
  and public.is_phone_verified(auth.uid())
  and public.is_account_action_allowed('listing',auth.uid())
);
drop policy if exists "Verified sellers update images" on storage.objects;
create policy "Verified sellers update images" on storage.objects for update to authenticated
using (bucket_id in ('shop-logos','product-images') and owner_id=auth.uid()::text
  and public.is_phone_verified(auth.uid())
  and public.is_account_action_allowed('listing',auth.uid()));
drop policy if exists "Verified sellers delete images" on storage.objects;
create policy "Verified sellers delete images" on storage.objects for delete to authenticated
using (bucket_id in ('shop-logos','product-images') and owner_id=auth.uid()::text
  and public.is_phone_verified(auth.uid())
  and public.is_account_action_allowed('listing',auth.uid()));
drop policy if exists "Users upload own review images" on storage.objects;
create policy "Users upload own review images" on storage.objects for insert to authenticated
with check (bucket_id='review-images'
  and (storage.foldername(name))[1]=auth.uid()::text
  and public.is_account_action_allowed('review',auth.uid()));
drop policy if exists "Users delete own review images" on storage.objects;
create policy "Users delete own review images" on storage.objects for delete to authenticated
using (bucket_id='review-images' and owner_id=auth.uid()::text
  and public.is_account_action_allowed('review',auth.uid()));

create or replace function public.get_my_access_context()
returns jsonb language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare
  v_role text; v_permissions jsonb; v_control public.account_controls%rowtype;
  v_status text;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  select * into v_control from public.account_controls c where c.user_id=auth.uid();
  v_status:=public.get_account_status(auth.uid());
  select r.role into v_role from public.user_roles r where r.user_id=auth.uid();
  select coalesce(jsonb_agg(p.permission order by p.permission),'[]'::jsonb)
    into v_permissions from public.admin_role_permissions p where p.role=v_role;
  return jsonb_build_object(
    'user_id',auth.uid(),'status',v_status,'role',v_role,
    'permissions',coalesce(v_permissions,'[]'::jsonb),
    'reason_public',case when v_status='active' then null else v_control.reason_public end,
    'restricted_until',case when v_status='suspended' then v_control.suspended_until else null end
  );
end; $$;

create or replace function public.admin_target_is_actionable(p_target_user uuid)
returns boolean language plpgsql stable security definer
set search_path=public,pg_temp as $$
begin
  if not public.is_admin() then
    raise exception 'Admin permission required.';
  end if;
  return auth.uid() is not null and p_target_user<>auth.uid()
    and not exists(select 1 from public.user_roles r where r.user_id=p_target_user);
end;
$$;

create or replace function public.admin_list_users(
  p_search text default null,
  p_status text default null,
  p_role text default null,
  p_has_shop boolean default null
) returns table(
  user_id uuid,full_name text,username text,masked_email text,masked_phone text,
  avatar_url text,status text,restricted_until timestamptz,role text,
  is_shop_owner boolean,order_count bigint,report_count bigint,created_at timestamptz
) language plpgsql stable security definer
set search_path=public,auth,pg_temp as $$
begin
  if not (public.has_admin_permission('users.view')
    or public.has_admin_permission('users.suspend')) then
    raise exception 'You do not have permission to view users.';
  end if;
  return query
  select p.id,p.full_name,p.username,
    case when position('@' in p.email)>1 then left(p.email,2)||'***@'||split_part(p.email,'@',2)
      else '***' end,
    case when length(p.mobile_number)>=4 then '*******'||right(p.mobile_number,4) else '***' end,
    p.avatar_url,public.get_account_status(p.id),c.suspended_until,r.role,
    exists(select 1 from public.shops s where s.owner_id=p.id),
    (select count(*) from public.orders o where o.buyer_id=p.id or o.seller_id=p.id),
    0::bigint,p.created_at
  from public.profiles p
  left join public.account_controls c on c.user_id=p.id
  left join public.user_roles r on r.user_id=p.id
  where (p_search is null or trim(p_search)='' or p.full_name ilike '%'||trim(p_search)||'%'
      or p.username ilike '%'||trim(p_search)||'%')
    and (p_status is null or public.get_account_status(p.id)=p_status)
    and (p_role is null or r.role=p_role)
    and (p_has_shop is null or p_has_shop=exists(
      select 1 from public.shops s where s.owner_id=p.id
    ))
  order by p.created_at desc limit 200;
end; $$;

create or replace function public.admin_get_user_detail(p_user_id uuid)
returns jsonb language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare v_result jsonb;
begin
  if not (public.has_admin_permission('users.view')
    or public.has_admin_permission('users.suspend')) then
    raise exception 'You do not have permission to view users.';
  end if;
  select jsonb_build_object(
    'user_id',p.id,'full_name',p.full_name,'username',p.username,
    'masked_email',case when position('@' in p.email)>1
      then left(p.email,2)||'***@'||split_part(p.email,'@',2) else '***' end,
    'masked_phone',case when length(p.mobile_number)>=4
      then '*******'||right(p.mobile_number,4) else '***' end,
    'avatar_url',p.avatar_url,'status',public.get_account_status(p.id),
    'restricted_until',c.suspended_until,'reason_public',c.reason_public,
    'role',r.role,'is_admin',r.user_id is not null,
    'shop',(select jsonb_build_object('id',s.id,'name',s.name,'location',s.location)
      from public.shops s where s.owner_id=p.id),
    'order_count',(select count(*) from public.orders o
      where o.buyer_id=p.id or o.seller_id=p.id),
    'status_history',coalesce((select jsonb_agg(jsonb_build_object(
      'status',h.status,'restricted_until',h.suspended_until,
      'reason_public',h.reason_public,'set_at',h.set_at,'set_by',h.set_by
    ) order by h.set_at desc) from public.account_status_history h
      where h.user_id=p.id),'[]'::jsonb)
  ) into v_result from public.profiles p
  left join public.account_controls c on c.user_id=p.id
  left join public.user_roles r on r.user_id=p.id where p.id=p_user_id;
  if v_result is null then raise exception 'User not found.'; end if;
  return v_result;
end; $$;

create or replace function public.admin_reveal_user_contact(
  p_user_id uuid,p_reason text
) returns jsonb language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_profile public.profiles%rowtype;
begin
  if not (public.has_admin_permission('users.view')
    or public.has_admin_permission('users.suspend')) then
    raise exception 'You do not have permission to reveal contact information.';
  end if;
  if not public.admin_target_is_actionable(p_user_id) then
    raise exception 'You cannot reveal your own or another admin account.';
  end if;
  select * into v_profile from public.profiles where id=p_user_id;
  if v_profile.id is null then raise exception 'User not found.'; end if;
  perform public.write_admin_audit(
    'user.contact_revealed','user',p_user_id,null,
    jsonb_build_object('fields',jsonb_build_array('email','phone')),
    p_reason,null
  );
  return jsonb_build_object('email',v_profile.email,'phone',v_profile.mobile_number);
end; $$;

create or replace function public.admin_set_account_control(
  p_user_id uuid,p_status text,p_suspended_until timestamptz,
  p_reason_public text,p_reason_internal text,p_reason text
) returns jsonb language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('users.suspend') then
    raise exception 'You do not have permission to moderate accounts.';
  end if;
  if not public.admin_target_is_actionable(p_user_id) then
    raise exception 'You cannot alter yourself or another admin account.';
  end if;
  if p_status not in ('active','suspended','banned') then raise exception 'Invalid account status.'; end if;
  if p_status='suspended' and p_suspended_until is not null and p_suspended_until<=now() then
    raise exception 'Suspension end time must be in the future.';
  end if;
  if char_length(trim(coalesce(p_reason_public,''))) not between 10 and 500
     or char_length(trim(coalesce(p_reason_internal,''))) not between 10 and 1000 then
    raise exception 'Enter clear public and internal reasons.';
  end if;
  if not exists(select 1 from public.profiles where id=p_user_id) then
    raise exception 'User not found.';
  end if;
  select to_jsonb(c) into v_before from public.account_controls c where c.user_id=p_user_id;
  v_after:=jsonb_build_object(
    'user_id',p_user_id,'status',p_status,
    'suspended_until',case when p_status='suspended' then p_suspended_until else null end,
    'reason_public',trim(p_reason_public),'reason_internal',trim(p_reason_internal),
    'set_by',auth.uid()
  );
  if v_before is not null
    and v_before->>'status'=p_status
    and coalesce(v_before->>'suspended_until','')=coalesce(v_after->>'suspended_until','')
    and v_before->>'reason_public'=trim(p_reason_public)
    and v_before->>'reason_internal'=trim(p_reason_internal) then
    return v_after;
  end if;
  insert into public.account_controls(
    user_id,status,suspended_until,reason_public,reason_internal,set_by,set_at
  ) values(
    p_user_id,p_status,case when p_status='suspended' then p_suspended_until end,
    trim(p_reason_public),trim(p_reason_internal),auth.uid(),now()
  ) on conflict(user_id) do update set
    status=excluded.status,suspended_until=excluded.suspended_until,
    reason_public=excluded.reason_public,reason_internal=excluded.reason_internal,
    set_by=excluded.set_by,set_at=excluded.set_at;
  insert into public.account_status_history(
    user_id,status,suspended_until,reason_public,reason_internal,set_by
  ) values(
    p_user_id,p_status,case when p_status='suspended' then p_suspended_until end,
    trim(p_reason_public),trim(p_reason_internal),auth.uid()
  );
  perform public.write_admin_audit(
    'user.'||p_status,'user',p_user_id,v_before,v_after,p_reason,null
  );
  return v_after;
end; $$;

revoke all on function public.get_account_status(uuid) from public,anon,authenticated;
revoke all on function public.is_account_action_allowed(text,uuid) from public,anon;
revoke all on function public.assert_account_allowed(text) from public,anon;
revoke all on function public.enforce_actor_account_action() from public,anon,authenticated;
revoke all on function public.enforce_order_account_action() from public,anon,authenticated;
revoke all on function public.enforce_return_account_action() from public,anon,authenticated;
revoke all on function public.enforce_wallet_account_action() from public,anon,authenticated;
revoke all on function public.account_can_read(uuid) from public,anon;
revoke all on function public.admin_target_is_actionable(uuid) from public,anon,authenticated;
revoke all on function public.admin_list_users(text,text,text,boolean) from public,anon;
revoke all on function public.admin_get_user_detail(uuid) from public,anon;
revoke all on function public.admin_reveal_user_contact(uuid,text) from public,anon;
revoke all on function public.admin_set_account_control(uuid,text,timestamptz,text,text,text) from public,anon;

grant execute on function public.is_account_action_allowed(text,uuid) to authenticated;
grant execute on function public.assert_account_allowed(text) to authenticated;
grant execute on function public.account_can_read(uuid) to authenticated;
-- Used by admin-set-auth-ban with the caller's JWT; the function performs its
-- own live role-table admin check before returning target information. The
-- Edge Function additionally requires users.suspend before calling it.
grant execute on function public.admin_target_is_actionable(uuid) to authenticated;
grant execute on function public.admin_list_users(text,text,text,boolean) to authenticated;
grant execute on function public.admin_get_user_detail(uuid) to authenticated;
grant execute on function public.admin_reveal_user_contact(uuid,text) to authenticated;
grant execute on function public.admin_set_account_control(uuid,text,timestamptz,text,text,text) to authenticated;

notify pgrst,'reload schema';
