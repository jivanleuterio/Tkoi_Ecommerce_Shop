-- Remove the demo verification entry point and setting.
-- Accounts already verified through the demo remain verified.

drop function if exists public.verify_demo_phone(text);
alter table public.marketplace_settings
  drop column if exists demo_phone_verification_enabled;

notify pgrst,'reload schema';
