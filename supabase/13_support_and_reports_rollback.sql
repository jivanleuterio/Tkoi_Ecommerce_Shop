-- Roll back only objects created by 13_support_and_reports.sql.

drop function if exists public.admin_view_ticket_conversation(uuid,text);
drop function if exists public.admin_resolve_report(uuid,text,text,text);
drop function if exists public.admin_list_reports(text,text);
drop function if exists public.admin_reply_ticket(uuid,text,boolean,text);
drop function if exists public.admin_update_ticket(uuid,text,text,uuid,text);
drop function if exists public.admin_get_ticket_detail(uuid);
drop function if exists public.admin_list_tickets(text,text,text,boolean);
drop function if exists public.create_report(text,uuid,text,text);
drop function if exists public.get_my_support_ticket_messages(uuid);
drop function if exists public.get_my_support_tickets();
drop function if exists public.add_support_ticket_message(uuid,text);
drop function if exists public.create_support_ticket(text,text,text,uuid,uuid,uuid,uuid);
drop function if exists public.validate_support_relations(uuid,uuid,uuid,uuid);

alter table if exists public.admin_audit_log
  drop constraint if exists admin_audit_log_ticket_id_fkey;
drop table if exists public.reports;
drop table if exists public.ticket_messages;
drop table if exists public.support_tickets;

notify pgrst,'reload schema';
