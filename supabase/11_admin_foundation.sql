-- Tkoi admin foundation: protected roles, permission matrix, and audit log.
-- Run after 10_demo_withdrawal.sql. Additive and safe to run twice.

create table if not exists public.admin_role_permissions (
  role text not null check (role in ('super_admin','moderator','finance')),
  permission text not null check (
    char_length(trim(permission)) between 1 and 100
    and permission !~ '[<>]'
  ),
  primary key(role,permission)
);

insert into public.admin_role_permissions(role,permission) values
  ('super_admin','*'),
  ('moderator','users.suspend'),
  ('moderator','content.moderate'),
  ('moderator','reports.*'),
  ('moderator','tickets.view'),
  ('finance','withdrawals.*'),
  ('finance','wallet.view'),
  ('finance','orders.view'),
  ('finance','returns.decide'),
  ('finance','settings.view')
on conflict(role,permission) do nothing;

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin','moderator','finance')),
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users(id) on delete restrict,
  action text not null check (
    char_length(trim(action)) between 2 and 120 and action !~ '[<>]'
  ),
  target_type text not null check (
    char_length(trim(target_type)) between 2 and 80 and target_type !~ '[<>]'
  ),
  target_id uuid,
  before_state jsonb,
  after_state jsonb,
  reason text not null check (
    char_length(trim(reason)) between 10 and 1000 and reason !~ '[<>]'
  ),
  ticket_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_admin_idx
  on public.admin_audit_log(admin_id,created_at desc);
create index if not exists admin_audit_log_target_idx
  on public.admin_audit_log(target_type,target_id,created_at desc);
create index if not exists admin_audit_log_ticket_idx
  on public.admin_audit_log(ticket_id,created_at desc)
  where ticket_id is not null;

alter table public.admin_role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.admin_audit_log enable row level security;

revoke all on table public.admin_role_permissions from anon,authenticated;
revoke all on table public.user_roles from anon,authenticated;
revoke all on table public.admin_audit_log from anon,authenticated;

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
  select exists(
    select 1 from public.user_roles r where r.user_id=auth.uid()
  );
$$;

create or replace function public.has_admin_permission(p_permission text)
returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
  select exists(
    select 1
    from public.user_roles r
    join public.admin_role_permissions p on p.role=r.role
    where r.user_id=auth.uid()
      and (
        p.permission='*'
        or p.permission=p_permission
        or (
          right(p.permission,2)='.*'
          and p_permission like left(p.permission,length(p.permission)-1)||'%'
        )
      )
  );
$$;

create or replace function public.write_admin_audit(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_before_state jsonb,
  p_after_state jsonb,
  p_reason text,
  p_ticket_id uuid default null
) returns uuid language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required.'; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 10 and 1000
     or coalesce(p_reason,'')~'[<>]' then
    raise exception 'Enter a reason of at least 10 characters.';
  end if;
  insert into public.admin_audit_log(
    admin_id,action,target_type,target_id,before_state,after_state,reason,ticket_id
  ) values(
    auth.uid(),trim(p_action),trim(p_target_type),p_target_id,
    p_before_state,p_after_state,trim(p_reason),p_ticket_id
  ) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.prevent_admin_audit_mutation()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  raise exception 'Admin audit entries are immutable.';
end; $$;

drop trigger if exists admin_audit_log_immutable on public.admin_audit_log;
create trigger admin_audit_log_immutable
before update or delete on public.admin_audit_log
for each row execute function public.prevent_admin_audit_mutation();

-- Phase 2 replaces the default account state with the protected moderation
-- state. Defining the RPC now lets the Flutter routing ship independently.
create or replace function public.get_my_access_context()
returns jsonb language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare v_role text; v_permissions jsonb;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  select r.role into v_role from public.user_roles r where r.user_id=auth.uid();
  select coalesce(jsonb_agg(p.permission order by p.permission),'[]'::jsonb)
    into v_permissions
  from public.admin_role_permissions p where p.role=v_role;
  return jsonb_build_object(
    'user_id',auth.uid(),
    'status','active',
    'role',v_role,
    'permissions',coalesce(v_permissions,'[]'::jsonb),
    'reason_public',null,
    'restricted_until',null
  );
end; $$;

create or replace function public.get_admin_team()
returns table(
  user_id uuid,role text,full_name text,username text,
  avatar_url text,granted_by uuid,granted_at timestamptz
) language plpgsql stable security definer
set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('roles.view') then
    raise exception 'You do not have permission to view admin roles.';
  end if;
  return query
  select r.user_id,r.role,
    coalesce(nullif(trim(p.full_name),''),'Tkoi admin'),p.username,p.avatar_url,
    r.granted_by,r.granted_at
  from public.user_roles r
  left join public.profiles p on p.id=r.user_id
  order by r.granted_at;
end; $$;

revoke all on function public.is_admin() from public,anon;
revoke all on function public.has_admin_permission(text) from public,anon;
revoke all on function public.write_admin_audit(
  text,text,uuid,jsonb,jsonb,text,uuid
) from public,anon,authenticated;
revoke all on function public.prevent_admin_audit_mutation() from public,anon,authenticated;
revoke all on function public.get_my_access_context() from public,anon;
revoke all on function public.get_admin_team() from public,anon;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.has_admin_permission(text) to authenticated;
grant execute on function public.get_my_access_context() to authenticated;
grant execute on function public.get_admin_team() to authenticated;

notify pgrst,'reload schema';
