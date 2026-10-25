-- Roll back only migration 05. This deletes wallet history; back up first.
begin;
do $$ begin
  if to_regclass('public.order_returns') is not null then
    execute 'drop trigger if exists order_returns_reverse_wallet on public.order_returns';
  end if;
end $$;
drop trigger if exists orders_release_wallet_escrow on public.orders;
drop trigger if exists orders_record_paid_wallet_sale on public.orders;
drop trigger if exists orders_set_fulfillment_timestamps on public.orders;
drop function if exists public.backfill_seller_wallet();
drop function if exists public.preview_seller_wallet_backfill();
drop function if exists public.get_seller_wallet_transactions(uuid,text);
drop function if exists public.get_seller_wallet_summary(uuid);
drop function if exists public.release_due_seller_escrows();
drop function if exists public.wallet_on_return_resolved();
drop function if exists public.wallet_on_order_completed();
drop function if exists public.wallet_on_order_payment();
drop function if exists public.reverse_order_earnings(uuid);
drop function if exists public.release_order_escrow(uuid);
drop function if exists public.record_xendit_sale_pending(uuid);
drop function if exists public.order_return_has_any_status(uuid,text[]);
drop function if exists public.set_order_fulfillment_timestamps();
drop trigger if exists seller_wallet_immutable on public.seller_wallet_transactions;
drop function if exists public.prevent_wallet_ledger_mutation();
drop table if exists public.seller_wallet_transactions;
drop table if exists public.marketplace_settings;
alter table public.orders drop column if exists completed_at;
alter table public.orders drop column if exists shipped_at;
commit;
notify pgrst,'reload schema';
