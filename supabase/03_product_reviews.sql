-- Tkoi product-level reviews and review photos.
-- Additive and safe to rerun. The legacy order_reviews table is untouched.

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (
    char_length(comment) <= 1000 and comment !~ '[<>]'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.review_images (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.product_reviews(id) on delete cascade,
  image_url text not null,
  storage_path text not null unique,
  sort_order integer not null check (sort_order between 0 and 4),
  created_at timestamptz not null default now(),
  unique(review_id, sort_order)
);

create index if not exists product_reviews_product_idx
  on public.product_reviews(product_id, created_at desc);
create index if not exists product_reviews_buyer_idx
  on public.product_reviews(buyer_id, created_at desc);
create index if not exists product_reviews_order_idx
  on public.product_reviews(order_id);
create index if not exists review_images_review_idx
  on public.review_images(review_id, sort_order);

drop trigger if exists product_reviews_set_updated_at on public.product_reviews;
create trigger product_reviews_set_updated_at
before update on public.product_reviews
for each row execute function public.set_updated_at();

alter table public.product_reviews enable row level security;
alter table public.review_images enable row level security;

revoke all on table public.product_reviews from anon;
revoke all on table public.review_images from anon;
revoke insert, update, delete on table public.product_reviews from authenticated;
revoke insert, update, delete on table public.review_images from authenticated;
grant select on table public.product_reviews to authenticated;
grant select on table public.review_images to authenticated;

drop policy if exists "Authenticated users read product reviews" on public.product_reviews;
create policy "Authenticated users read product reviews"
on public.product_reviews for select to authenticated using (true);

drop policy if exists "Authenticated users read review images" on public.review_images;
create policy "Authenticated users read review images"
on public.review_images for select to authenticated using (true);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'review-images','review-images',true,5242880,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Public reads review images" on storage.objects;
create policy "Public reads review images"
on storage.objects for select
using (bucket_id='review-images');

drop policy if exists "Users upload own review images" on storage.objects;
create policy "Users upload own review images"
on storage.objects for insert to authenticated
with check (
  bucket_id='review-images'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "Users delete own review images" on storage.objects;
create policy "Users delete own review images"
on storage.objects for delete to authenticated
using (bucket_id='review-images' and owner_id=auth.uid()::text);

create or replace function public.submit_product_review(
  p_order_item_id uuid,
  p_rating integer,
  p_comment text default '',
  p_image_urls text[] default '{}'::text[],
  p_storage_paths text[] default '{}'::text[]
) returns uuid language plpgsql security definer set search_path=public,storage as $$
declare
  v_item record;
  v_review_id uuid;
  v_index integer;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  if p_rating not between 1 and 5 then raise exception 'Choose a rating from 1 to 5.'; end if;
  if char_length(trim(coalesce(p_comment,'')))>1000 or coalesce(p_comment,'')~'[<>]' then
    raise exception 'Enter a valid review of up to 1000 characters.';
  end if;
  if cardinality(p_image_urls)<>cardinality(p_storage_paths)
     or cardinality(p_image_urls)>5 then
    raise exception 'Add no more than 5 review photos.';
  end if;

  select oi.id,oi.order_id,oi.product_id,oi.seller_id,oi.shop_id,
         o.buyer_id,o.status
  into v_item
  from public.order_items oi
  join public.orders o on o.id=oi.order_id
  where oi.id=p_order_item_id
  for update of oi,o;

  if v_item.id is null or v_item.buyer_id<>auth.uid() then
    raise exception 'Purchased item not found.';
  end if;
  if v_item.product_id is null then raise exception 'This product is no longer available to review.'; end if;
  if v_item.status<>'completed' then raise exception 'Receive the order before reviewing this item.'; end if;
  if exists(select 1 from public.product_reviews where order_item_id=p_order_item_id) then
    raise exception 'You already reviewed this purchased item.';
  end if;
  if exists(
    select 1 from public.order_returns
    where order_id=v_item.order_id and status not in ('rejected','cancelled','resolved')
  ) then raise exception 'Finish the return request before reviewing this item.'; end if;

  if cardinality(p_storage_paths)>0 then
    for v_index in 1..cardinality(p_storage_paths) loop
      if p_storage_paths[v_index] not like auth.uid()::text||'/%'
         or not exists(
           select 1 from storage.objects so
           where so.bucket_id='review-images'
             and so.name=p_storage_paths[v_index]
             and so.owner_id=auth.uid()::text
         ) then
        raise exception 'A review photo could not be verified.';
      end if;
    end loop;
  end if;

  insert into public.product_reviews(
    order_item_id,order_id,product_id,buyer_id,seller_id,shop_id,rating,comment
  ) values(
    v_item.id,v_item.order_id,v_item.product_id,v_item.buyer_id,
    v_item.seller_id,v_item.shop_id,p_rating,trim(coalesce(p_comment,''))
  ) returning id into v_review_id;

  if cardinality(p_image_urls)>0 then
    for v_index in 1..cardinality(p_image_urls) loop
      insert into public.review_images(review_id,image_url,storage_path,sort_order)
      values(v_review_id,p_image_urls[v_index],p_storage_paths[v_index],v_index-1);
    end loop;
  end if;
  return v_review_id;
end; $$;

create or replace function public.get_product_reviews(
  p_product_id uuid,
  p_rating integer default null,
  p_with_photos boolean default false
) returns table (
  id uuid,
  order_item_id uuid,
  product_id uuid,
  rating integer,
  comment text,
  created_at timestamptz,
  buyer_name text,
  buyer_avatar text,
  images jsonb
)
language sql stable security definer set search_path=public as $$
  select
    r.id,r.order_item_id,r.product_id,r.rating,r.comment,r.created_at,
    coalesce(nullif(trim(p.full_name),''),'Tkoi buyer') as buyer_name,
    p.avatar_url as buyer_avatar,
    coalesce((
      select jsonb_agg(
        jsonb_build_object('url',ri.image_url,'sort_order',ri.sort_order)
        order by ri.sort_order
      )
      from public.review_images ri where ri.review_id=r.id
    ),'[]'::jsonb) as images
  from public.product_reviews r
  join public.profiles p on p.id=r.buyer_id
  where r.product_id=p_product_id
    and (p_rating is null or r.rating=p_rating)
    and (not p_with_photos or exists(
      select 1 from public.review_images ri where ri.review_id=r.id
    ))
  order by r.created_at desc;
$$;

create or replace function public.get_product_stats(p_product_ids uuid[])
returns table (
  product_id uuid,
  sold_count bigint,
  heart_count bigint,
  average_rating numeric,
  total_reviews bigint,
  rating_5 bigint,
  rating_4 bigint,
  rating_3 bigint,
  rating_2 bigint,
  rating_1 bigint
)
language sql stable security definer set search_path=public as $$
  select
    p.id,
    coalesce(s.sold_count,0)::bigint,
    coalesce(h.heart_count,0)::bigint,
    coalesce(r.average_rating,0)::numeric,
    coalesce(r.total_reviews,0)::bigint,
    coalesce(r.rating_5,0)::bigint,
    coalesce(r.rating_4,0)::bigint,
    coalesce(r.rating_3,0)::bigint,
    coalesce(r.rating_2,0)::bigint,
    coalesce(r.rating_1,0)::bigint
  from public.products p
  left join lateral (
    select sum(oi.quantity)::bigint sold_count
    from public.order_items oi
    join public.orders o on o.id=oi.order_id
    where oi.product_id=p.id and o.status='completed'
  ) s on true
  left join lateral (
    select count(*)::bigint heart_count
    from public.product_favorites f where f.product_id=p.id
  ) h on true
  left join lateral (
    select round(avg(pr.rating)::numeric,1) average_rating,
      count(*)::bigint total_reviews,
      count(*) filter(where pr.rating=5)::bigint rating_5,
      count(*) filter(where pr.rating=4)::bigint rating_4,
      count(*) filter(where pr.rating=3)::bigint rating_3,
      count(*) filter(where pr.rating=2)::bigint rating_2,
      count(*) filter(where pr.rating=1)::bigint rating_1
    from public.product_reviews pr where pr.product_id=p.id
  ) r on true
  where p.id=any(coalesce(p_product_ids,'{}'::uuid[]));
$$;

revoke all on function public.submit_product_review(uuid,integer,text,text[],text[]) from public;
revoke all on function public.get_product_reviews(uuid,integer,boolean) from public;
revoke all on function public.get_product_stats(uuid[]) from public;
grant execute on function public.submit_product_review(uuid,integer,text,text[],text[]) to authenticated;
grant execute on function public.get_product_reviews(uuid,integer,boolean) to authenticated;
grant execute on function public.get_product_stats(uuid[]) to authenticated;

notify pgrst, 'reload schema';
