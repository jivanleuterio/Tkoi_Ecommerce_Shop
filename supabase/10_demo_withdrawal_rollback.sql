-- Roll back the demo RPC only. Existing demo ledger/history is preserved.
drop function if exists public.request_demo_seller_withdrawal(uuid,numeric,uuid);
notify pgrst,'reload schema';
