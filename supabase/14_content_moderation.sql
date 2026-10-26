-- Tkoi soft content moderation for shops, listings, reviews, and review images.
-- Run after 13_support_and_reports.sql. Additive and safe to run twice.

alter table public.products
  add column if not exists moderation_status text not null default 'clear',
  add column if not exists moderation_reason text not null default '',
  add column if not exists moderated_by uuid references auth.users(id) on delete set null,
  add column if not exists moderated_at timestamptz;
alter table public.shops
  add column if not exists moderation_status text not null default 'clear',
  add column if not exists moderation_reason text not null default '',
  add column if not exists moderated_by uuid references auth.users(id) on delete set null,
  add column if not exists moderated_at timestamptz;
alter table public.product_reviews
  add column if not exists moderation_status text not null default 'clear',
  add column if not exists moderation_reason text not null default '',
  add column if not exists moderated_by uuid references auth.users(id) on delete set null,
  add column if not exists moderated_at timestamptz;
alter table public.review_images
  add column if not exists moderation_status text not null default 'clear',
  add column if not exists moderation_reason text not null default '',
  add column if not exists moderated_by uuid references auth.users(id) on delete set null,
  add column if not exists moderated_at timestamptz;

do $$
begin
  if not exists(select 1 from pg_constraint where conname='products_moderation_status_check') then
    alter table public.products add constraint products_moderation_status_check
      check(moderation_status in ('clear','under_review','removed')) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='shops_moderation_status_check') then
    alter table public.shops add constraint shops_moderation_status_check
      check(moderation_status in ('clear','under_review','removed')) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='product_reviews_moderation_status_check') then
    alter table public.product_reviews add constraint product_reviews_moderation_status_check
      check(moderation_status in ('clear','under_review','removed')) not valid;
  end if;
  if not exists(select 1 from pg_constraint where conname='review_images_moderation_status_check') then
    alter table public.review_images add constraint review_images_moderation_status_check
      check(moderation_status in ('clear','under_review','removed')) not valid;
  end if;
end $$;

create index if not exists products_moderation_idx
  on public.products(moderation_status,created_at desc);
create index if not exists shops_moderation_idx
  on public.shops(moderation_status,created_at desc);
create index if not exists product_reviews_moderation_idx
  on public.product_reviews(moderation_status,created_at desc);

create or replace function public.protect_moderation_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_old jsonb; v_new jsonb;
begin
  if auth.uid() is null or public.has_admin_permission('content.moderate') then
    return new;
  end if;
  v_new:=to_jsonb(new);
  if tg_op='INSERT' then
    if coalesce(v_new->>'moderation_status','clear')<>'clear'
       or coalesce(v_new->>'moderation_reason','')<>''
       or v_new->>'moderated_by' is not null
       or v_new->>'moderated_at' is not null then
      raise exception 'Moderation fields can only be changed by an authorized admin.';
    end if;
    return new;
  end if;
  v_old:=to_jsonb(old);
  if v_new->'moderation_status' is distinct from v_old->'moderation_status'
     or v_new->'moderation_reason' is distinct from v_old->'moderation_reason'
     or v_new->'moderated_by' is distinct from v_old->'moderated_by'
     or v_new->'moderated_at' is distinct from v_old->'moderated_at' then
    raise exception 'Moderation fields can only be changed by an authorized admin.';
  end if;
  return new;
end; $$;

drop trigger if exists products_protect_moderation on public.products;
create trigger products_protect_moderation before insert or update on public.products
for each row execute function public.protect_moderation_fields();
drop trigger if exists shops_protect_moderation on public.shops;
create trigger shops_protect_moderation before insert or update on public.shops
for each row execute function public.protect_moderation_fields();
drop trigger if exists product_reviews_protect_moderation on public.product_reviews;
create trigger product_reviews_protect_moderation before insert or update on public.product_reviews
for each row execute function public.protect_moderation_fields();
drop trigger if exists review_images_protect_moderation on public.review_images;
create trigger review_images_protect_moderation before insert or update on public.review_images
for each row execute function public.protect_moderation_fields();

create or replace function public.product_content_is_clear(p_product_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(
    select 1 from public.products p join public.shops s on s.id=p.shop_id
    where p.id=p_product_id and p.moderation_status='clear'
      and s.moderation_status='clear'
  );
$$;

create or replace function public.enforce_product_content_available()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_product_id uuid;
begin
  if auth.uid() is null then return new; end if;
  v_product_id:=case when tg_table_name='order_items' then new.product_id else new.product_id end;
  if v_product_id is not null and not public.product_content_is_clear(v_product_id) then
    raise exception 'This listing is currently unavailable.';
  end if;
  return new;
end; $$;

drop trigger if exists cart_items_content_available on public.cart_items;
create trigger cart_items_content_available before insert or update on public.cart_items
for each row execute function public.enforce_product_content_available();
drop trigger if exists product_favorites_content_available on public.product_favorites;
create trigger product_favorites_content_available before insert on public.product_favorites
for each row execute function public.enforce_product_content_available();
drop trigger if exists order_items_content_available on public.order_items;
create trigger order_items_content_available before insert on public.order_items
for each row execute function public.enforce_product_content_available();

drop policy if exists "Anyone views shops" on public.shops;
create policy "Anyone views shops" on public.shops for select using (
  (auth.uid() is null or public.account_can_read(auth.uid()))
  and (moderation_status='clear' or owner_id=auth.uid())
);

drop policy if exists "Public views active products and sellers view own" on public.products;
create policy "Public views active products and sellers view own" on public.products
for select using (
  (auth.uid() is null or public.account_can_read(auth.uid())) and (
    seller_id=auth.uid() or (
      moderation_status='clear'
      and exists(select 1 from public.shops s
        where s.id=shop_id and s.moderation_status='clear')
      and status='available' and quantity>0
    )
  )
);

drop policy if exists "Users view images for visible products" on public.product_images;
create policy "Users view images for visible products" on public.product_images
for select using (
  (auth.uid() is null or public.account_can_read(auth.uid())) and exists(
    select 1 from public.products p join public.shops s on s.id=p.shop_id
    where p.id=product_id and (
      p.seller_id=auth.uid() or (
        p.moderation_status='clear' and s.moderation_status='clear'
        and p.status='available' and p.quantity>0
      )
    )
  )
);

drop policy if exists "Authenticated users read product reviews" on public.product_reviews;
create policy "Authenticated users read product reviews" on public.product_reviews
for select to authenticated using (
  public.account_can_read(auth.uid())
  and (moderation_status='clear' or buyer_id=auth.uid() or seller_id=auth.uid())
);
drop policy if exists "Authenticated users read review images" on public.review_images;
create policy "Authenticated users read review images" on public.review_images
for select to authenticated using (
  public.account_can_read(auth.uid()) and exists(
    select 1 from public.product_reviews r where r.id=review_id
      and (r.moderation_status='clear' or r.buyer_id=auth.uid() or r.seller_id=auth.uid())
  ) and (moderation_status='clear' or exists(
    select 1 from public.product_reviews r where r.id=review_id
      and (r.buyer_id=auth.uid() or r.seller_id=auth.uid())
  ))
);

create or replace function public.get_product_reviews(
  p_product_id uuid,
  p_rating integer default null,
  p_with_photos boolean default false
) returns table (
  id uuid,order_item_id uuid,product_id uuid,rating integer,comment text,
  created_at timestamptz,buyer_name text,buyer_avatar text,images jsonb
) language sql stable security definer set search_path=public,pg_temp as $$
  select r.id,r.order_item_id,r.product_id,r.rating,r.comment,r.created_at,
    coalesce(nullif(trim(p.full_name),''),'Tkoi buyer'),p.avatar_url,
    coalesce((select jsonb_agg(jsonb_build_object(
      'url',ri.image_url,'sort_order',ri.sort_order
    ) order by ri.sort_order) from public.review_images ri
      where ri.review_id=r.id and ri.moderation_status='clear'),'[]'::jsonb)
  from public.product_reviews r join public.profiles p on p.id=r.buyer_id
  where r.product_id=p_product_id and r.moderation_status='clear'
    and (p_rating is null or r.rating=p_rating)
    and (not p_with_photos or exists(select 1 from public.review_images ri
      where ri.review_id=r.id and ri.moderation_status='clear'))
  order by r.created_at desc;
$$;

create or replace function public.get_product_stats(p_product_ids uuid[])
returns table (
  product_id uuid,sold_count bigint,heart_count bigint,average_rating numeric,
  total_reviews bigint,rating_5 bigint,rating_4 bigint,rating_3 bigint,
  rating_2 bigint,rating_1 bigint
) language sql stable security definer set search_path=public,pg_temp as $$
  select p.id,
    coalesce((select sum(oi.quantity)::bigint from public.order_items oi
      join public.orders o on o.id=oi.order_id
      where oi.product_id=p.id and o.status='completed'),0)::bigint,
    coalesce((select count(*) from public.product_favorites f
      where f.product_id=p.id),0)::bigint,
    coalesce(round(avg(r.rating)::numeric,1),0)::numeric,
    count(r.id)::bigint,
    count(r.id) filter(where r.rating=5)::bigint,
    count(r.id) filter(where r.rating=4)::bigint,
    count(r.id) filter(where r.rating=3)::bigint,
    count(r.id) filter(where r.rating=2)::bigint,
    count(r.id) filter(where r.rating=1)::bigint
  from public.products p left join public.product_reviews r
    on r.product_id=p.id and r.moderation_status='clear'
  where p.id=any(coalesce(p_product_ids,'{}'::uuid[]))
  group by p.id;
$$;

create or replace function public.admin_list_moderation_content(
  p_content_type text,
  p_status text default null,
  p_search text default null
) returns table(
  id uuid,content_type text,title text,subtitle text,image_url text,
  moderation_status text,moderation_reason text,owner_id uuid,
  created_at timestamptz
) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.has_admin_permission('content.moderate') then
    raise exception 'You do not have permission to moderate content.';
  end if;
  if p_content_type not in ('product','shop','review') then
    raise exception 'Choose a valid content type.';
  end if;
  if p_content_type='product' then
    return query select p.id,'product'::text,p.name,
      concat(s.name,' · ',p.status),
      (select pi.image_url from public.product_images pi where pi.product_id=p.id
        order by pi.sort_order,pi.created_at limit 1),
      p.moderation_status,p.moderation_reason,p.seller_id,p.created_at
    from public.products p join public.shops s on s.id=p.shop_id
    where (p_status is null or p.moderation_status=p_status)
      and (p_search is null or trim(p_search)='' or p.name ilike '%'||trim(p_search)||'%')
    order by p.created_at desc limit 200;
  elsif p_content_type='shop' then
    return query select s.id,'shop'::text,s.name,s.location,s.logo_url,
      s.moderation_status,s.moderation_reason,s.owner_id,s.created_at
    from public.shops s where (p_status is null or s.moderation_status=p_status)
      and (p_search is null or trim(p_search)='' or s.name ilike '%'||trim(p_search)||'%')
    order by s.created_at desc limit 200;
  else
    return query select r.id,'review'::text,p.name,
      concat(r.rating,' stars · ',left(r.comment,120)),
      (select ri.image_url from public.review_images ri where ri.review_id=r.id
        order by ri.sort_order limit 1),
      r.moderation_status,r.moderation_reason,r.buyer_id,r.created_at
    from public.product_reviews r join public.products p on p.id=r.product_id
    where (p_status is null or r.moderation_status=p_status)
      and (p_search is null or trim(p_search)='' or p.name ilike '%'||trim(p_search)||'%'
        or r.comment ilike '%'||trim(p_search)||'%')
    order by r.created_at desc limit 200;
  end if;
end; $$;

create or replace function public.admin_set_content_moderation(
  p_content_type text,
  p_content_id uuid,
  p_status text,
  p_reason text,
  p_report_id uuid default null,
  p_ticket_id uuid default null
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_before jsonb; v_after jsonb;
begin
  if not public.has_admin_permission('content.moderate') then
    raise exception 'You do not have permission to moderate content.';
  end if;
  if p_status not in ('clear','under_review','removed') then
    raise exception 'Invalid moderation status.';
  end if;
  if char_length(trim(coalesce(p_reason,''))) not between 10 and 1000
     or coalesce(p_reason,'')~'[<>]' then
    raise exception 'Enter a moderation reason of at least 10 characters.';
  end if;
  if p_content_type='product' then
    select p.seller_id,to_jsonb(p) into v_owner,v_before from public.products p
      where p.id=p_content_id for update;
  elsif p_content_type='shop' then
    select s.owner_id,to_jsonb(s) into v_owner,v_before from public.shops s
      where s.id=p_content_id for update;
  elsif p_content_type='review' then
    select r.buyer_id,to_jsonb(r) into v_owner,v_before from public.product_reviews r
      where r.id=p_content_id for update;
  else raise exception 'Choose a valid content type.';
  end if;
  if v_owner is null then raise exception 'Content not found.'; end if;
  if not public.admin_target_is_actionable(v_owner) then
    raise exception 'You cannot moderate content owned by yourself or another admin.';
  end if;
  if v_before->>'moderation_status'=p_status
     and coalesce(v_before->>'moderation_reason','')=(
       case when p_status='clear' then '' else trim(p_reason) end
     ) then
    return;
  end if;
  if p_report_id is not null and not exists(select 1 from public.reports r
    where r.id=p_report_id and r.target_type=p_content_type and r.target_id=p_content_id) then
    raise exception 'The linked report does not match this content.';
  end if;
  if p_content_type='product' then
    update public.products set moderation_status=p_status,
      moderation_reason=case when p_status='clear' then '' else trim(p_reason) end,
      moderated_by=auth.uid(),moderated_at=now() where id=p_content_id;
    select to_jsonb(p) into v_after from public.products p where p.id=p_content_id;
  elsif p_content_type='shop' then
    update public.shops set moderation_status=p_status,
      moderation_reason=case when p_status='clear' then '' else trim(p_reason) end,
      moderated_by=auth.uid(),moderated_at=now() where id=p_content_id;
    select to_jsonb(s) into v_after from public.shops s where s.id=p_content_id;
  else
    update public.product_reviews set moderation_status=p_status,
      moderation_reason=case when p_status='clear' then '' else trim(p_reason) end,
      moderated_by=auth.uid(),moderated_at=now() where id=p_content_id;
    update public.review_images set moderation_status=p_status,
      moderation_reason=case when p_status='clear' then '' else trim(p_reason) end,
      moderated_by=auth.uid(),moderated_at=now() where review_id=p_content_id;
    select to_jsonb(r) into v_after from public.product_reviews r where r.id=p_content_id;
  end if;
  perform public.write_admin_audit(
    'content.'||p_status,p_content_type,p_content_id,v_before,v_after,
    p_reason,p_ticket_id
  );
  if p_report_id is not null then
    update public.reports set status='actioned',handled_by=auth.uid(),
      resolution_note='Content moderation action: '||p_status||'. '||trim(p_reason)
    where id=p_report_id and status not in ('actioned','dismissed');
  end if;
end; $$;

create or replace function public.get_seller_moderation_notices(p_shop_id uuid)
returns table(product_id uuid,product_name text,moderation_status text,reason text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not exists(select 1 from public.shops s where s.id=p_shop_id and s.owner_id=auth.uid()) then
    raise exception 'Shop not found.';
  end if;
  return query select p.id,p.name,p.moderation_status,p.moderation_reason
  from public.products p where p.shop_id=p_shop_id and p.moderation_status<>'clear'
  order by p.moderated_at desc nulls last;
end; $$;

revoke all on function public.protect_moderation_fields() from public,anon,authenticated;
revoke all on function public.product_content_is_clear(uuid) from public,anon;
revoke all on function public.enforce_product_content_available() from public,anon,authenticated;
revoke all on function public.admin_list_moderation_content(text,text,text) from public,anon;
revoke all on function public.admin_set_content_moderation(text,uuid,text,text,uuid,uuid) from public,anon;
revoke all on function public.get_seller_moderation_notices(uuid) from public,anon;
grant execute on function public.product_content_is_clear(uuid) to authenticated;
grant execute on function public.admin_list_moderation_content(text,text,text) to authenticated;
grant execute on function public.admin_set_content_moderation(text,uuid,text,text,uuid,uuid) to authenticated;
grant execute on function public.get_seller_moderation_notices(uuid) to authenticated;

notify pgrst,'reload schema';
