-- Tkoi buyer/seller conversations and realtime text messages.
-- One conversation per buyer/seller pair. Additive and safe to rerun.

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  last_product_id uuid references public.products(id) on delete set null,
  last_order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conversations_distinct_participants check (buyer_id<>seller_id),
  unique(buyer_id,seller_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (
    char_length(trim(body)) between 1 and 2000 and body !~ '[<>]'
  ),
  product_id uuid references public.products(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists conversations_buyer_idx
  on public.conversations(buyer_id, updated_at desc);
create index if not exists conversations_seller_idx
  on public.conversations(seller_id, updated_at desc);
create index if not exists messages_conversation_idx
  on public.messages(conversation_id, created_at);
create index if not exists messages_unread_idx
  on public.messages(conversation_id, sender_id, read_at)
  where read_at is null;

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.messages replica identity full;

revoke all on table public.conversations from anon;
revoke all on table public.messages from anon;
revoke insert, update, delete on table public.conversations from authenticated;
revoke insert, update, delete on table public.messages from authenticated;
grant select on table public.conversations to authenticated;
grant select on table public.messages to authenticated;

drop policy if exists "Participants view conversations" on public.conversations;
create policy "Participants view conversations"
on public.conversations for select to authenticated
using (buyer_id=auth.uid() or seller_id=auth.uid());

drop policy if exists "Participants view messages" on public.messages;
create policy "Participants view messages"
on public.messages for select to authenticated
using (
  exists(
    select 1 from public.conversations c
    where c.id=conversation_id
      and (c.buyer_id=auth.uid() or c.seller_id=auth.uid())
  )
);

create or replace function public.get_or_create_conversation(
  p_seller_id uuid,
  p_product_id uuid default null,
  p_order_id uuid default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_conversation_id uuid;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if p_seller_id=v_user then raise exception 'You cannot chat with yourself.'; end if;
  if not exists(select 1 from public.shops s where s.owner_id=p_seller_id) then
    raise exception 'Seller not found.';
  end if;
  if p_product_id is not null and not exists(
    select 1 from public.products p
    where p.id=p_product_id and p.seller_id=p_seller_id
  ) then raise exception 'Product chat context is invalid.'; end if;
  if p_order_id is not null and not exists(
    select 1 from public.orders o
    where o.id=p_order_id and o.buyer_id=v_user and o.seller_id=p_seller_id
  ) then raise exception 'Order chat context is invalid.'; end if;

  insert into public.conversations(
    buyer_id,seller_id,last_product_id,last_order_id
  ) values(v_user,p_seller_id,p_product_id,p_order_id)
  on conflict(buyer_id,seller_id) do update set
    last_product_id=coalesce(excluded.last_product_id,public.conversations.last_product_id),
    last_order_id=coalesce(excluded.last_order_id,public.conversations.last_order_id),
    updated_at=now()
  returning id into v_conversation_id;
  return v_conversation_id;
end; $$;

create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_body text,
  p_product_id uuid default null,
  p_order_id uuid default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_user uuid:=auth.uid();
  v_conversation public.conversations%rowtype;
  v_message_id uuid;
begin
  if v_user is null then raise exception 'Please sign in again.'; end if;
  if char_length(trim(coalesce(p_body,''))) not between 1 and 2000
     or coalesce(p_body,'')~'[<>]' then
    raise exception 'Enter a message of up to 2000 characters.';
  end if;
  select * into v_conversation from public.conversations
  where id=p_conversation_id for update;
  if v_conversation.id is null or v_user not in (
    v_conversation.buyer_id,v_conversation.seller_id
  ) then raise exception 'Conversation not found.'; end if;
  if p_product_id is not null and not exists(
    select 1 from public.products p
    where p.id=p_product_id and p.seller_id=v_conversation.seller_id
  ) then raise exception 'Product chat context is invalid.'; end if;
  if p_order_id is not null and not exists(
    select 1 from public.orders o
    where o.id=p_order_id
      and o.buyer_id=v_conversation.buyer_id
      and o.seller_id=v_conversation.seller_id
  ) then raise exception 'Order chat context is invalid.'; end if;

  insert into public.messages(
    conversation_id,sender_id,body,product_id,order_id
  ) values(
    p_conversation_id,v_user,trim(p_body),p_product_id,p_order_id
  ) returning id into v_message_id;
  update public.conversations set
    last_product_id=coalesce(p_product_id,last_product_id),
    last_order_id=coalesce(p_order_id,last_order_id),
    updated_at=now()
  where id=p_conversation_id;
  return v_message_id;
end; $$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(
    select 1 from public.conversations c
    where c.id=p_conversation_id
      and (c.buyer_id=auth.uid() or c.seller_id=auth.uid())
  ) then raise exception 'Conversation not found.'; end if;
  update public.messages set read_at=now()
  where conversation_id=p_conversation_id
    and sender_id<>auth.uid() and read_at is null;
end; $$;

create or replace function public.get_chat_inbox()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_name text,
  other_avatar text,
  shop_name text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  product_id uuid,
  product_name text,
  product_image text,
  order_id uuid
)
language sql stable security definer set search_path=public as $$
  select
    c.id,
    case when c.buyer_id=auth.uid() then c.seller_id else c.buyer_id end,
    coalesce(nullif(trim(other_profile.full_name),''),'Tkoi user'),
    other_profile.avatar_url,
    seller_shop.name,
    last_message.body,
    coalesce(last_message.created_at,c.updated_at),
    (select count(*) from public.messages unread
      where unread.conversation_id=c.id
        and unread.sender_id<>auth.uid() and unread.read_at is null)::bigint,
    c.last_product_id,
    context_product.name,
    (select pi.image_url from public.product_images pi
      where pi.product_id=context_product.id
      order by pi.sort_order,pi.created_at limit 1),
    c.last_order_id
  from public.conversations c
  join public.profiles other_profile on other_profile.id=(
    case when c.buyer_id=auth.uid() then c.seller_id else c.buyer_id end
  )
  left join public.shops seller_shop on seller_shop.owner_id=c.seller_id
  left join public.products context_product on context_product.id=c.last_product_id
  left join lateral (
    select m.body,m.created_at from public.messages m
    where m.conversation_id=c.id order by m.created_at desc limit 1
  ) last_message on true
  where c.buyer_id=auth.uid() or c.seller_id=auth.uid()
  order by coalesce(last_message.created_at,c.updated_at) desc;
$$;

create or replace function public.get_chat_context(p_conversation_id uuid)
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_name text,
  other_avatar text,
  shop_name text,
  product_id uuid,
  product_name text,
  product_image text,
  order_id uuid
)
language sql stable security definer set search_path=public as $$
  select
    c.id,
    case when c.buyer_id=auth.uid() then c.seller_id else c.buyer_id end,
    coalesce(nullif(trim(other_profile.full_name),''),'Tkoi user'),
    other_profile.avatar_url,
    seller_shop.name,
    c.last_product_id,
    context_product.name,
    (select pi.image_url from public.product_images pi
      where pi.product_id=context_product.id
      order by pi.sort_order,pi.created_at limit 1),
    c.last_order_id
  from public.conversations c
  join public.profiles other_profile on other_profile.id=(
    case when c.buyer_id=auth.uid() then c.seller_id else c.buyer_id end
  )
  left join public.shops seller_shop on seller_shop.owner_id=c.seller_id
  left join public.products context_product on context_product.id=c.last_product_id
  where c.id=p_conversation_id
    and (c.buyer_id=auth.uid() or c.seller_id=auth.uid());
$$;

revoke all on function public.get_or_create_conversation(uuid,uuid,uuid) from public;
revoke all on function public.send_chat_message(uuid,text,uuid,uuid) from public;
revoke all on function public.mark_conversation_read(uuid) from public;
revoke all on function public.get_chat_inbox() from public;
revoke all on function public.get_chat_context(uuid) from public;
grant execute on function public.get_or_create_conversation(uuid,uuid,uuid) to authenticated;
grant execute on function public.send_chat_message(uuid,text,uuid,uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.get_chat_inbox() to authenticated;
grant execute on function public.get_chat_context(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
