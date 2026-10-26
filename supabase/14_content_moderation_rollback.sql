-- Roll back only objects created by 14_content_moderation.sql.

drop function if exists public.get_seller_moderation_notices(uuid);
drop function if exists public.admin_set_content_moderation(text,uuid,text,text,uuid,uuid);
drop function if exists public.admin_list_moderation_content(text,text,text);
drop function if exists public.enforce_product_content_available();
drop function if exists public.product_content_is_clear(uuid);
drop function if exists public.protect_moderation_fields();

drop trigger if exists order_items_content_available on public.order_items;
drop trigger if exists product_favorites_content_available on public.product_favorites;
drop trigger if exists cart_items_content_available on public.cart_items;
drop trigger if exists review_images_protect_moderation on public.review_images;
drop trigger if exists product_reviews_protect_moderation on public.product_reviews;
drop trigger if exists shops_protect_moderation on public.shops;
drop trigger if exists products_protect_moderation on public.products;

alter table if exists public.review_images
  drop constraint if exists review_images_moderation_status_check,
  drop column if exists moderation_status,
  drop column if exists moderation_reason,
  drop column if exists moderated_by,
  drop column if exists moderated_at;
alter table if exists public.product_reviews
  drop constraint if exists product_reviews_moderation_status_check,
  drop column if exists moderation_status,
  drop column if exists moderation_reason,
  drop column if exists moderated_by,
  drop column if exists moderated_at;
alter table if exists public.shops
  drop constraint if exists shops_moderation_status_check,
  drop column if exists moderation_status,
  drop column if exists moderation_reason,
  drop column if exists moderated_by,
  drop column if exists moderated_at;
alter table if exists public.products
  drop constraint if exists products_moderation_status_check,
  drop column if exists moderation_status,
  drop column if exists moderation_reason,
  drop column if exists moderated_by,
  drop column if exists moderated_at;

notify pgrst,'reload schema';
