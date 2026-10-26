-- Tkoi self-contained demo phone verification.
-- Run after 17_account_action_trigger_fix.sql. Additive and safe to run twice.
-- This is for classroom/demo use only and does not send a real SMS.

alter table public.marketplace_settings
  add column if not exists demo_phone_verification_enabled boolean
    not null default true;

create or replace function public.verify_demo_phone(p_phone text)
returns boolean language plpgsql security definer
set search_path=public,auth,pg_temp as $$
declare
  v_user uuid:=auth.uid();
  v_phone text:=trim(coalesce(p_phone,''));
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if not coalesce((select demo_phone_verification_enabled
    from public.marketplace_settings where singleton=true),false) then
    raise exception 'Demo phone verification is disabled.';
  end if;
  perform public.assert_account_allowed('profile');

  if v_phone !~ '^\+639[0-9]{9}$' then
    raise exception 'Enter a valid Philippine mobile number such as +639171234567.';
  end if;
  if exists(select 1 from auth.users u
    where u.phone=v_phone and u.id<>v_user) then
    raise exception 'This mobile number is already used by another account.';
  end if;

  update auth.users set
    phone=v_phone,
    phone_confirmed_at=case
      when phone is distinct from v_phone then now()
      else coalesce(phone_confirmed_at,now())
    end,
    updated_at=now()
  where id=v_user;
  if not found then raise exception 'Account not found.'; end if;

  update public.profiles set mobile_number=v_phone where id=v_user;
  return true;
end; $$;

revoke all on function public.verify_demo_phone(text) from public,anon;
grant execute on function public.verify_demo_phone(text) to authenticated;

notify pgrst,'reload schema';
