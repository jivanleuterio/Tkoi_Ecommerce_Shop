-- Roll back account moderation objects created by 12_account_moderation.sql.
-- Re-run security_hardening.sql and migrations 01, 03, 04, 05, and 06 after
-- this rollback to restore their original policies.

drop function if exists public.admin_set_account_control(uuid,text,timestamptz,text,text,text);
drop function if exists public.admin_reveal_user_contact(uuid,text);
drop function if exists public.admin_get_user_detail(uuid);
drop function if exists public.admin_list_users(text,text,text,boolean);
drop function if exists public.admin_target_is_actionable(uuid);

drop trigger if exists seller_wallet_transactions_account_action on public.seller_wallet_transactions;
drop trigger if exists withdrawal_requests_account_action on public.withdrawal_requests;
drop trigger if exists seller_payout_accounts_account_action on public.seller_payout_accounts;
drop trigger if exists messages_account_action on public.messages;
drop trigger if exists conversations_account_action on public.conversations;
drop trigger if exists order_returns_account_action on public.order_returns;
drop trigger if exists order_reviews_account_action on public.order_reviews;
drop trigger if exists review_images_account_action on public.review_images;
drop trigger if exists product_reviews_account_action on public.product_reviews;
drop trigger if exists product_favorites_account_action on public.product_favorites;
drop trigger if exists orders_account_action on public.orders;
drop trigger if exists payment_transactions_account_action on public.payment_transactions;
drop trigger if exists cart_items_account_action on public.cart_items;
drop trigger if exists product_images_account_action on public.product_images;
drop trigger if exists products_account_action on public.products;
drop trigger if exists shops_account_action on public.shops;
drop trigger if exists profiles_account_action on public.profiles;

drop function if exists public.enforce_return_account_action();
drop function if exists public.enforce_wallet_account_action();
drop function if exists public.enforce_order_account_action();
drop function if exists public.enforce_actor_account_action();
drop function if exists public.account_can_read(uuid);
drop function if exists public.assert_account_allowed(text);
drop function if exists public.is_account_action_allowed(text,uuid);
drop function if exists public.get_account_status(uuid);
drop table if exists public.account_status_history;
drop table if exists public.account_controls;

notify pgrst,'reload schema';
