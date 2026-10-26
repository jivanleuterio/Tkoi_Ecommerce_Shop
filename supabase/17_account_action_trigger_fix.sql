-- Tkoi account-action trigger hotfix.
-- Run after 12_account_moderation.sql. Additive and safe to run twice.
--
-- The original generic trigger referenced NEW.seller_id in a compound
-- expression. PostgreSQL could evaluate that field access for messages and
-- other tables without a seller_id column, which blocked chat sends with:
--   record "new" has no field "seller_id"

create or replace function public.enforce_actor_account_action()
returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
begin
  if auth.uid() is not null then
    -- Buyer-side order completion/cancellation RPCs legitimately restore a
    -- seller's product stock. That inventory write is not a buyer listing
    -- edit; RLS still prevents a buyer from directly editing the product.
    --
    -- Keep seller_id access inside the product-only branch because NEW is a
    -- different record shape for every table that uses this trigger.
    if tg_table_name='products' and tg_op='UPDATE' then
      if new.seller_id<>auth.uid() then
        return new;
      end if;
    end if;
    perform public.assert_account_allowed(tg_argv[0]);
  end if;
  if tg_op='DELETE' then
    return old;
  end if;
  return new;
end; $$;

revoke all on function public.enforce_actor_account_action()
  from public,anon,authenticated;

notify pgrst,'reload schema';
