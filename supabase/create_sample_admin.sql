-- ONE-TIME DEMO ADMIN ACCOUNT CREATOR
-- Run only after 11_admin_foundation.sql in the Supabase SQL Editor.
-- Do not use these public demo credentials in a production deployment.
-- After testing, change the password from Supabase Authentication or delete
-- this demo account and grant super_admin to your real private account.

do $$
declare
  v_email constant text := 'admin.demo@tkoi.test';
  v_password constant text := 'TkoiAdmin!2026#Koi7';
  v_user_id uuid;
  v_username text;
begin
  select u.id into v_user_id
  from auth.users u
  where lower(u.email)=lower(v_email);

  if v_user_id is null then
    v_user_id:=gen_random_uuid();
    v_username:='tkoi_admin_'||left(v_user_id::text,8);

    insert into auth.users(
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
      confirmation_token,email_change,email_change_token_new,recovery_token
    ) values(
      '00000000-0000-0000-0000-000000000000',v_user_id,
      'authenticated','authenticated',v_email,
      crypt(v_password,gen_salt('bf')),now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'full_name','Tkoi Demo Admin',
        'username',v_username,
        'mobile_number','09100000000',
        'address','Tkoi administration'
      ),
      now(),now(),'','','',''
    );

    -- Current Supabase Auth installations use this email identity when
    -- resolving password logins. The conflict guard makes the script safe to
    -- retry if the Auth trigger/installation already created the identity.
    insert into auth.identities(
      provider_id,user_id,identity_data,provider,
      last_sign_in_at,created_at,updated_at
    ) values(
      v_user_id::text,v_user_id,
      jsonb_build_object('sub',v_user_id::text,'email',v_email),
      'email',now(),now(),now()
    ) on conflict(provider_id,provider) do nothing;
  end if;

  v_username:=coalesce(v_username,'tkoi_admin_'||left(v_user_id::text,8));

  -- Keep the public profile present even on databases where the Auth profile
  -- trigger was not installed or was temporarily disabled.
  insert into public.profiles(
    id,full_name,username,email,mobile_number,address
  ) values(
    v_user_id,'Tkoi Demo Admin',v_username,v_email,
    '09100000000','Tkoi administration'
  ) on conflict(id) do update set
    full_name=excluded.full_name;

  insert into public.user_roles(user_id,role,granted_by)
  values(v_user_id,'super_admin',v_user_id)
  on conflict(user_id) do update set
    role='super_admin',granted_by=v_user_id,granted_at=now();

  raise notice 'Demo super admin is ready: %',v_email;
end $$;

select u.email,r.role,u.email_confirmed_at
from auth.users u
join public.user_roles r on r.user_id=u.id
where lower(u.email)=lower('admin.demo@tkoi.test');
