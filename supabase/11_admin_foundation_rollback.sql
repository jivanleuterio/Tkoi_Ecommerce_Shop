-- Roll back only objects created by 11_admin_foundation.sql.

drop function if exists public.get_admin_team();
drop function if exists public.get_my_access_context();
drop function if exists public.write_admin_audit(text,text,uuid,jsonb,jsonb,text,uuid);
drop trigger if exists admin_audit_log_immutable on public.admin_audit_log;
drop function if exists public.prevent_admin_audit_mutation();
drop function if exists public.has_admin_permission(text);
drop function if exists public.is_admin();
drop table if exists public.admin_audit_log;
drop table if exists public.user_roles;
drop table if exists public.admin_role_permissions;

notify pgrst,'reload schema';
