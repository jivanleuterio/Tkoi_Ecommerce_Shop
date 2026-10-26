-- Tkoi customer support tickets, appeals, and reports.
-- Run after 12_account_moderation.sql. Additive and safe to run twice.

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  category text not null check (category in (
    'account','order','payment','report','appeal','other'
  )),
  subject text not null check (
    char_length(trim(subject)) between 5 and 120 and subject !~ '[<>]'
  ),
  status text not null default 'open' check (status in (
    'open','in_progress','waiting_user','resolved','closed'
  )),
  priority text not null default 'normal' check (priority in (
    'low','normal','high','urgent'
  )),
  assigned_to uuid references auth.users(id) on delete set null,
  related_order_id uuid references public.orders(id) on delete set null,
  related_product_id uuid references public.products(id) on delete set null,
  related_shop_id uuid references public.shops(id) on delete set null,
  related_conversation_id uuid references public.conversations(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete restrict,
  sender_type text not null check (sender_type in ('user','agent')),
  body text not null check (
    char_length(trim(body)) between 1 and 4000 and body !~ '[<>]'
  ),
  is_internal_note boolean not null default false,
  created_at timestamptz not null default now(),
  constraint ticket_internal_notes_are_agent_only check (
    not is_internal_note or sender_type='agent'
  )
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete restrict,
  target_type text not null check (target_type in (
    'product','shop','user','review','message'
  )),
  target_id uuid not null,
  reason_category text not null check (
    char_length(trim(reason_category)) between 3 and 80
    and reason_category !~ '[<>]'
  ),
  details text not null check (
    char_length(trim(details)) between 10 and 1000 and details !~ '[<>]'
  ),
  status text not null default 'open' check (status in (
    'open','reviewing','actioned','dismissed'
  )),
  ticket_id uuid references public.support_tickets(id) on delete set null,
  created_at timestamptz not null default now(),
  handled_by uuid references auth.users(id) on delete set null,
  resolution_note text check (
    resolution_note is null or (
      char_length(trim(resolution_note)) between 10 and 1000
      and resolution_note !~ '[<>]'
    )
  )
);

create index if not exists support_tickets_user_idx
  on public.support_tickets(user_id,updated_at desc);
create index if not exists support_tickets_queue_idx
  on public.support_tickets(status,priority,updated_at desc);
create index if not exists support_tickets_assigned_idx
  on public.support_tickets(assigned_to,status,updated_at desc);
create index if not exists ticket_messages_ticket_idx
  on public.ticket_messages(ticket_id,created_at);
create index if not exists reports_reporter_idx
  on public.reports(reporter_id,created_at desc);
create index if not exists reports_queue_idx
  on public.reports(status,target_type,created_at desc);
create index if not exists reports_target_idx
  on public.reports(target_type,target_id,created_at desc);

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

alter table public.support_tickets enable row level security;
alter table public.ticket_messages enable row level security;
alter table public.reports enable row level security;

revoke all on table public.support_tickets from anon;
revoke all on table public.ticket_messages from anon;
revoke all on table public.reports from anon;
revoke insert,update,delete on table public.support_tickets from authenticated;
revoke insert,update,delete on table public.ticket_messages from authenticated;
revoke insert,update,delete on table public.reports from authenticated;
grant select on table public.support_tickets to authenticated;
grant select on table public.ticket_messages to authenticated;
grant select on table public.reports to authenticated;

drop policy if exists "Users view own support tickets" on public.support_tickets;
create policy "Users view own support tickets"
on public.support_tickets for select to authenticated
using (
  user_id=auth.uid() and (
    public.account_can_read(auth.uid()) or category='appeal'
  )
);

drop policy if exists "Users view own public ticket messages" on public.ticket_messages;
create policy "Users view own public ticket messages"
on public.ticket_messages for select to authenticated
using (
  not is_internal_note and exists(
    select 1 from public.support_tickets t
    where t.id=ticket_id and t.user_id=auth.uid()
      and (public.account_can_read(auth.uid()) or t.category='appeal')
  )
);

drop policy if exists "Users view own reports" on public.reports;
create policy "Users view own reports"
on public.reports for select to authenticated
using (
  reporter_id=auth.uid() and public.account_can_read(auth.uid())
);

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='admin_audit_log_ticket_id_fkey'
      and conrelid='public.admin_audit_log'::regclass
  ) then
    alter table public.admin_audit_log
      add constraint admin_audit_log_ticket_id_fkey
      foreign key(ticket_id) references public.support_tickets(id) on delete set null;
  end if;
end $$;

create or replace function public.validate_support_relations(
  p_order_id uuid,
  p_product_id uuid,
  p_shop_id uuid,
  p_conversation_id uuid
) returns void language plpgsql stable security definer
set search_path=public,pg_temp as $$
begin
  if p_order_id is not null and not exists(
    select 1 from public.orders o where o.id=p_order_id
      and auth.uid() in (o.buyer_id,o.seller_id)
  ) then raise exception 'Related order not found.'; end if;
  if p_product_id is not null and not exists(
    select 1 from public.products p where p.id=p_product_id
  ) then raise exception 'Related product not found.'; end if;
  if p_shop_id is not null and not exists(
    select 1 from public.shops s where s.id=p_shop_id
  ) then raise exception 'Related shop not found.'; end if;
  if p_conversation_id is not null and not exists(
    select 1 from public.conversations c where c.id=p_conversation_id
      and auth.uid() in (c.buyer_id,c.seller_id)
  ) then raise exception 'Related conversation not found.'; end if;
end; $$;

create or replace function public.create_support_ticket(
  p_category text,
  p_subject text,
  p_body text,
  p_related_order_id uuid default null,
  p_related_product_id uuid default null,
  p_related_shop_id uuid default null,
  p_related_conversation_id uuid default null
) returns uuid language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_ticket_id uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  if p_category not in ('account','order','payment','report','appeal','other') then
    raise exception 'Choose a valid support category.';
  end if;
  if public.get_account_status(auth.uid())='banned' and p_category<>'appeal' then
    raise exception 'A banned account can only submit an appeal.';
  end if;
  perform public.assert_account_allowed(
    case when p_category='appeal' then 'appeal' else 'support' end
  );
  if char_length(trim(coalesce(p_subject,''))) not between 5 and 120
     or coalesce(p_subject,'')~'[<>]' then
    raise exception 'Enter a subject using 5 to 120 characters.';
  end if;
  if char_length(trim(coalesce(p_body,''))) not between 10 and 4000
     or coalesce(p_body,'')~'[<>]' then
    raise exception 'Describe the issue using 10 to 4000 characters.';
  end if;
  if (select count(*) from public.support_tickets t
      where t.user_id=auth.uid()
        and t.status in ('open','in_progress','waiting_user'))>=5 then
    raise exception 'You already have 5 open support tickets. Please wait for a response.';
  end if;
  perform public.validate_support_relations(
    p_related_order_id,p_related_product_id,p_related_shop_id,p_related_conversation_id
  );
  insert into public.support_tickets(
    user_id,category,subject,related_order_id,related_product_id,
    related_shop_id,related_conversation_id
  ) values(
    auth.uid(),p_category,trim(p_subject),p_related_order_id,p_related_product_id,
    p_related_shop_id,p_related_conversation_id
  ) returning id into v_ticket_id;
  insert into public.ticket_messages(ticket_id,sender_id,sender_type,body)
  values(v_ticket_id,auth.uid(),'user',trim(p_body));
  return v_ticket_id;
end; $$;

create or replace function public.add_support_ticket_message(
  p_ticket_id uuid,
  p_body text
) returns uuid language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_ticket public.support_tickets%rowtype; v_message_id uuid;
begin
  select * into v_ticket from public.support_tickets
  where id=p_ticket_id and user_id=auth.uid() for update;
  if v_ticket.id is null then raise exception 'Support ticket not found.'; end if;
  perform public.assert_account_allowed(
    case when v_ticket.category='appeal' then 'appeal' else 'support' end
  );
  if v_ticket.status in ('resolved','closed') then
    raise exception 'This ticket is closed. Create a new ticket if you still need help.';
  end if;
  if char_length(trim(coalesce(p_body,''))) not between 1 and 4000
     or coalesce(p_body,'')~'[<>]' then
    raise exception 'Enter a message of up to 4000 characters.';
  end if;
  if (select count(*) from public.ticket_messages m
      where m.sender_id=auth.uid() and m.created_at>now()-interval '1 hour')>=30 then
    raise exception 'Too many support messages. Please try again later.';
  end if;
  insert into public.ticket_messages(ticket_id,sender_id,sender_type,body)
  values(p_ticket_id,auth.uid(),'user',trim(p_body)) returning id into v_message_id;
  update public.support_tickets set
    status=case when status='waiting_user' then 'open' else status end,
    updated_at=now()
  where id=p_ticket_id;
  return v_message_id;
end; $$;

create or replace function public.get_my_support_tickets()
returns table(
  id uuid,category text,subject text,status text,priority text,
  related_order_id uuid,related_product_id uuid,related_shop_id uuid,
  related_conversation_id uuid,created_at timestamptz,updated_at timestamptz,
  last_message text,last_message_at timestamptz
) language sql stable security definer set search_path=public,pg_temp as $$
  select t.id,t.category,t.subject,t.status,t.priority,
    t.related_order_id,t.related_product_id,t.related_shop_id,
    t.related_conversation_id,t.created_at,t.updated_at,
    last_message.body,last_message.created_at
  from public.support_tickets t
  left join lateral(
    select m.body,m.created_at from public.ticket_messages m
    where m.ticket_id=t.id and not m.is_internal_note
    order by m.created_at desc limit 1
  ) last_message on true
  where t.user_id=auth.uid()
    and (public.account_can_read(auth.uid()) or t.category='appeal')
  order by t.updated_at desc;
$$;

create or replace function public.get_my_support_ticket_messages(p_ticket_id uuid)
returns table(
  id uuid,sender_id uuid,sender_type text,body text,created_at timestamptz
) language sql stable security definer set search_path=public,pg_temp as $$
  select m.id,m.sender_id,m.sender_type,m.body,m.created_at
  from public.ticket_messages m
  join public.support_tickets t on t.id=m.ticket_id
  where m.ticket_id=p_ticket_id and t.user_id=auth.uid()
    and (public.account_can_read(auth.uid()) or t.category='appeal')
    and not m.is_internal_note
  order by m.created_at;
$$;

create or replace function public.create_report(
  p_target_type text,
  p_target_id uuid,
  p_reason_category text,
  p_details text
) returns uuid language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_report_id uuid; v_valid boolean:=false;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  perform public.assert_account_allowed('support');
  if p_target_type not in ('product','shop','user','review','message') then
    raise exception 'Choose a valid report type.';
  end if;
  if p_target_id is null then raise exception 'The reported item is missing.'; end if;
  if char_length(trim(coalesce(p_reason_category,''))) not between 3 and 80
     or coalesce(p_reason_category,'')~'[<>]' then
    raise exception 'Choose a valid report reason.';
  end if;
  if char_length(trim(coalesce(p_details,''))) not between 10 and 1000
     or coalesce(p_details,'')~'[<>]' then
    raise exception 'Describe the problem using 10 to 1000 characters.';
  end if;
  if (select count(*) from public.reports r
      where r.reporter_id=auth.uid()
        and r.created_at>=date_trunc('day',now()))>=10 then
    raise exception 'You reached today''s report limit.';
  end if;
  if p_target_type='product' then
    select exists(select 1 from public.products where id=p_target_id) into v_valid;
  elsif p_target_type='shop' then
    select exists(select 1 from public.shops where id=p_target_id) into v_valid;
  elsif p_target_type='user' then
    select exists(select 1 from public.profiles where id=p_target_id and id<>auth.uid()) into v_valid;
  elsif p_target_type='review' then
    select exists(select 1 from public.product_reviews where id=p_target_id) into v_valid;
  elsif p_target_type='message' then
    select exists(
      select 1 from public.messages m join public.conversations c on c.id=m.conversation_id
      where m.id=p_target_id and auth.uid() in (c.buyer_id,c.seller_id)
    ) into v_valid;
  end if;
  if not v_valid then raise exception 'The reported item was not found.'; end if;
  if exists(select 1 from public.reports r
    where r.reporter_id=auth.uid() and r.target_type=p_target_type
      and r.target_id=p_target_id and r.status in ('open','reviewing')) then
    raise exception 'You already reported this item.';
  end if;
  insert into public.reports(
    reporter_id,target_type,target_id,reason_category,details
  ) values(
    auth.uid(),p_target_type,p_target_id,trim(p_reason_category),trim(p_details)
  ) returning id into v_report_id;
  return v_report_id;
end; $$;

create or replace function public.admin_list_tickets(
  p_status text default null,
  p_category text default null,
  p_priority text default null,
  p_assigned_to_me boolean default false
) returns table(
  id uuid,user_id uuid,user_name text,user_avatar text,category text,
  subject text,status text,priority text,assigned_to uuid,
  related_order_id uuid,related_product_id uuid,related_shop_id uuid,
  related_conversation_id uuid,message_count bigint,created_at timestamptz,
  updated_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('tickets.view') then
    raise exception 'You do not have permission to view support tickets.';
  end if;
  return query
  select t.id,t.user_id,coalesce(nullif(trim(p.full_name),''),'Tkoi user'),
    p.avatar_url,t.category,t.subject,t.status,t.priority,t.assigned_to,
    t.related_order_id,t.related_product_id,t.related_shop_id,
    t.related_conversation_id,
    (select count(*) from public.ticket_messages m where m.ticket_id=t.id),
    t.created_at,t.updated_at
  from public.support_tickets t
  join public.profiles p on p.id=t.user_id
  where (p_status is null or t.status=p_status)
    and (p_category is null or t.category=p_category)
    and (p_priority is null or t.priority=p_priority)
    and (not p_assigned_to_me or t.assigned_to=auth.uid())
  order by
    case t.priority when 'urgent' then 0 when 'high' then 1
      when 'normal' then 2 else 3 end,
    t.updated_at desc;
end; $$;

create or replace function public.admin_get_ticket_detail(p_ticket_id uuid)
returns jsonb language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare v_result jsonb;
begin
  if not public.has_admin_permission('tickets.view') then
    raise exception 'You do not have permission to view support tickets.';
  end if;
  select jsonb_build_object(
    'id',t.id,'user_id',t.user_id,
    'user_name',coalesce(nullif(trim(p.full_name),''),'Tkoi user'),
    'user_avatar',p.avatar_url,'username',p.username,
    'account_status',public.get_account_status(t.user_id),
    'category',t.category,'subject',t.subject,'status',t.status,
    'priority',t.priority,'assigned_to',t.assigned_to,
    'related_order_id',t.related_order_id,
    'related_product_id',t.related_product_id,
    'related_shop_id',t.related_shop_id,
    'related_conversation_id',t.related_conversation_id,
    'created_at',t.created_at,'updated_at',t.updated_at,
    'messages',coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'sender_id',m.sender_id,'sender_type',m.sender_type,
      'sender_name',coalesce(nullif(trim(mp.full_name),''),
        case when m.sender_type='agent' then 'Tkoi support' else 'Tkoi user' end),
      'sender_avatar',mp.avatar_url,'body',m.body,
      'is_internal_note',m.is_internal_note,'created_at',m.created_at
    ) order by m.created_at)
    from public.ticket_messages m left join public.profiles mp on mp.id=m.sender_id
    where m.ticket_id=t.id),'[]'::jsonb)
  ) into v_result
  from public.support_tickets t join public.profiles p on p.id=t.user_id
  where t.id=p_ticket_id;
  if v_result is null then raise exception 'Support ticket not found.'; end if;
  return v_result;
end; $$;

create or replace function public.admin_update_ticket(
  p_ticket_id uuid,
  p_status text,
  p_priority text,
  p_assigned_to uuid,
  p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ticket public.support_tickets%rowtype; v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('tickets.manage') then
    raise exception 'You do not have permission to manage support tickets.';
  end if;
  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if v_ticket.id is null then raise exception 'Support ticket not found.'; end if;
  if not public.admin_target_is_actionable(v_ticket.user_id) then
    raise exception 'You cannot alter a ticket belonging to yourself or another admin.';
  end if;
  if p_status not in ('open','in_progress','waiting_user','resolved','closed') then
    raise exception 'Invalid ticket status.';
  end if;
  if p_priority not in ('low','normal','high','urgent') then
    raise exception 'Invalid ticket priority.';
  end if;
  if p_assigned_to is not null and not exists(
    select 1 from public.user_roles where user_id=p_assigned_to
  ) then raise exception 'Assigned agent is not an admin.'; end if;
  v_before:=to_jsonb(v_ticket);
  if v_ticket.status=p_status and v_ticket.priority=p_priority
    and v_ticket.assigned_to is not distinct from p_assigned_to then return; end if;
  update public.support_tickets set status=p_status,priority=p_priority,
    assigned_to=p_assigned_to,updated_at=now() where id=p_ticket_id;
  select to_jsonb(t) into v_after from public.support_tickets t where t.id=p_ticket_id;
  perform public.write_admin_audit(
    'ticket.update','support_ticket',p_ticket_id,v_before,v_after,p_reason,p_ticket_id
  );
end; $$;

create or replace function public.admin_reply_ticket(
  p_ticket_id uuid,
  p_body text,
  p_is_internal_note boolean,
  p_reason text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ticket public.support_tickets%rowtype; v_message_id uuid;
begin
  if not public.has_admin_permission('tickets.manage') then
    raise exception 'You do not have permission to manage support tickets.';
  end if;
  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if v_ticket.id is null then raise exception 'Support ticket not found.'; end if;
  if not public.admin_target_is_actionable(v_ticket.user_id) then
    raise exception 'You cannot alter a ticket belonging to yourself or another admin.';
  end if;
  if v_ticket.status='closed' then raise exception 'This ticket is closed.'; end if;
  if char_length(trim(coalesce(p_body,''))) not between 1 and 4000
     or coalesce(p_body,'')~'[<>]' then raise exception 'Enter a valid reply.'; end if;
  insert into public.ticket_messages(
    ticket_id,sender_id,sender_type,body,is_internal_note
  ) values(
    p_ticket_id,auth.uid(),'agent',trim(p_body),p_is_internal_note
  ) returning id into v_message_id;
  update public.support_tickets set
    status=case when p_is_internal_note then status else 'waiting_user' end,
    assigned_to=coalesce(assigned_to,auth.uid()),updated_at=now()
  where id=p_ticket_id;
  perform public.write_admin_audit(
    case when p_is_internal_note then 'ticket.internal_note' else 'ticket.reply' end,
    'support_ticket',p_ticket_id,null,
    jsonb_build_object('message_id',v_message_id,'internal',p_is_internal_note),
    p_reason,p_ticket_id
  );
  return v_message_id;
end; $$;

create or replace function public.admin_list_reports(
  p_status text default null,
  p_target_type text default null
) returns table(
  id uuid,reporter_id uuid,reporter_name text,target_type text,target_id uuid,
  reason_category text,details text,status text,ticket_id uuid,
  handled_by uuid,resolution_note text,created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('reports.view') then
    raise exception 'You do not have permission to view reports.';
  end if;
  return query select r.id,r.reporter_id,
    coalesce(nullif(trim(p.full_name),''),'Tkoi user'),r.target_type,r.target_id,
    r.reason_category,r.details,r.status,r.ticket_id,r.handled_by,
    r.resolution_note,r.created_at
  from public.reports r join public.profiles p on p.id=r.reporter_id
  where (p_status is null or r.status=p_status)
    and (p_target_type is null or r.target_type=p_target_type)
  order by r.created_at desc;
end; $$;

create or replace function public.admin_resolve_report(
  p_report_id uuid,
  p_status text,
  p_resolution_note text,
  p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_report public.reports%rowtype; v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('reports.manage') then
    raise exception 'You do not have permission to manage reports.';
  end if;
  select * into v_report from public.reports where id=p_report_id for update;
  if v_report.id is null then raise exception 'Report not found.'; end if;
  if not public.admin_target_is_actionable(v_report.reporter_id) then
    raise exception 'You cannot alter a report submitted by yourself or another admin.';
  end if;
  if v_report.target_type='user' and not public.admin_target_is_actionable(v_report.target_id) then
    raise exception 'You cannot take action on yourself or another admin.';
  end if;
  if p_status not in ('reviewing','actioned','dismissed') then
    raise exception 'Invalid report status.';
  end if;
  if char_length(trim(coalesce(p_resolution_note,''))) not between 10 and 1000
     or coalesce(p_resolution_note,'')~'[<>]' then
    raise exception 'Enter a resolution note of at least 10 characters.';
  end if;
  if v_report.status=p_status
    and v_report.resolution_note=trim(p_resolution_note) then return; end if;
  v_before:=to_jsonb(v_report);
  update public.reports set status=p_status,handled_by=auth.uid(),
    resolution_note=trim(p_resolution_note) where id=p_report_id;
  select to_jsonb(r) into v_after from public.reports r where r.id=p_report_id;
  perform public.write_admin_audit(
    'report.'||p_status,'report',p_report_id,v_before,v_after,p_reason,v_report.ticket_id
  );
end; $$;

create or replace function public.admin_view_ticket_conversation(
  p_ticket_id uuid,
  p_reason text
) returns table(
  message_id uuid,sender_id uuid,sender_name text,sender_avatar text,
  body text,created_at timestamptz,product_id uuid,order_id uuid
) language plpgsql security definer set search_path=public,pg_temp as $$
declare v_conversation_id uuid; v_ticket_status text;
begin
  if not public.has_admin_permission('chat.view_via_ticket') then
    raise exception 'You do not have permission to view ticket-linked chats.';
  end if;
  select t.related_conversation_id,t.status
    into v_conversation_id,v_ticket_status
  from public.support_tickets t where t.id=p_ticket_id;
  if v_ticket_status is null then raise exception 'Support ticket not found.'; end if;
  if v_ticket_status in ('resolved','closed') then
    raise exception 'Chat access requires an open support ticket or report.';
  end if;
  if v_conversation_id is null then
    select m.conversation_id into v_conversation_id
    from public.reports r join public.messages m on m.id=r.target_id
    where r.ticket_id=p_ticket_id and r.target_type='message'
      and r.status in ('open','reviewing')
    order by r.created_at desc limit 1;
  end if;
  if v_conversation_id is null then
    raise exception 'This ticket is not linked to a conversation.';
  end if;
  perform public.write_admin_audit(
    'chat.view_via_ticket','conversation',v_conversation_id,null,
    jsonb_build_object('ticket_id',p_ticket_id),p_reason,p_ticket_id
  );
  return query
  select m.id,m.sender_id,
    coalesce(nullif(trim(p.full_name),''),'Tkoi user'),p.avatar_url,
    m.body,m.created_at,m.product_id,m.order_id
  from public.messages m join public.profiles p on p.id=m.sender_id
  where m.conversation_id=v_conversation_id
  order by m.created_at;
end; $$;

revoke all on function public.validate_support_relations(uuid,uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function public.create_support_ticket(text,text,text,uuid,uuid,uuid,uuid) from public,anon;
revoke all on function public.add_support_ticket_message(uuid,text) from public,anon;
revoke all on function public.get_my_support_tickets() from public,anon;
revoke all on function public.get_my_support_ticket_messages(uuid) from public,anon;
revoke all on function public.create_report(text,uuid,text,text) from public,anon;
revoke all on function public.admin_list_tickets(text,text,text,boolean) from public,anon;
revoke all on function public.admin_get_ticket_detail(uuid) from public,anon;
revoke all on function public.admin_update_ticket(uuid,text,text,uuid,text) from public,anon;
revoke all on function public.admin_reply_ticket(uuid,text,boolean,text) from public,anon;
revoke all on function public.admin_list_reports(text,text) from public,anon;
revoke all on function public.admin_resolve_report(uuid,text,text,text) from public,anon;
revoke all on function public.admin_view_ticket_conversation(uuid,text) from public,anon;

grant execute on function public.create_support_ticket(text,text,text,uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.add_support_ticket_message(uuid,text) to authenticated;
grant execute on function public.get_my_support_tickets() to authenticated;
grant execute on function public.get_my_support_ticket_messages(uuid) to authenticated;
grant execute on function public.create_report(text,uuid,text,text) to authenticated;
grant execute on function public.admin_list_tickets(text,text,text,boolean) to authenticated;
grant execute on function public.admin_get_ticket_detail(uuid) to authenticated;
grant execute on function public.admin_update_ticket(uuid,text,text,uuid,text) to authenticated;
grant execute on function public.admin_reply_ticket(uuid,text,boolean,text) to authenticated;
grant execute on function public.admin_list_reports(text,text) to authenticated;
grant execute on function public.admin_resolve_report(uuid,text,text,text) to authenticated;
grant execute on function public.admin_view_ticket_conversation(uuid,text) to authenticated;

notify pgrst,'reload schema';
