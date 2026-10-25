-- Tkoi persistent product favorites.
-- Additive and safe to rerun. No existing tables or rows are removed.

create table if not exists public.product_favorites (
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (buyer_id, product_id)
);

create index if not exists product_favorites_product_idx
  on public.product_favorites(product_id, created_at desc);
create index if not exists product_favorites_buyer_idx
  on public.product_favorites(buyer_id, created_at desc);

alter table public.product_favorites enable row level security;

revoke all on table public.product_favorites from anon;
grant select, insert, delete on table public.product_favorites to authenticated;

drop policy if exists "Users view own favorites" on public.product_favorites;
create policy "Users view own favorites"
on public.product_favorites for select to authenticated
using (buyer_id=auth.uid());

drop policy if exists "Users add own favorites" on public.product_favorites;
create policy "Users add own favorites"
on public.product_favorites for insert to authenticated
with check (
  buyer_id=auth.uid()
  and exists(select 1 from public.products p where p.id=product_id)
);

drop policy if exists "Users remove own favorites" on public.product_favorites;
create policy "Users remove own favorites"
on public.product_favorites for delete to authenticated
using (buyer_id=auth.uid());

notify pgrst, 'reload schema';
