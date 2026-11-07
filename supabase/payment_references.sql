-- =============================================================================
-- FairTix — payment details on primary ticket purchases.
-- Run in the Supabase SQL Editor AFTER purchase_functions.sql and
-- resale_payment.sql (which creates transactions.payment_ref), then re-run
-- my_transactions.sql. Safe to re-run. Run this BEFORE deploying the updated
-- paymongo-verify / paymongo-webhook Edge Functions: they call the 6-argument
-- fulfill_ticket_purchase below. The 3-argument version in
-- purchase_functions.sql stays in place, so the currently deployed functions
-- keep working until you redeploy.
--
-- WHAT IS STORED (on public.transactions, for a primary purchase)
--   payment_ref         PayMongo checkout session / payment intent id of the
--                       payment, prefixed 'FTX-TK-' (resale uses 'FTX-RS-'
--                       the same way). Also the idempotency key; unique.
--   provider_payment_id The PayMongo payment id ('pay_...') when PayMongo
--                       returned one, else NULL.
--   payment_method      How the buyer paid as reported by PayMongo, lower
--                       case ('gcash', 'paymaya', 'card'), else NULL.
--
-- LEGACY ROWS stay NULL on purpose: purchases made before this file have no
-- recorded payment details, and nothing here infers them (the ticket's QR
-- token happens to contain the session id, but a token is not a payment
-- record, so it is never parsed or copied).
-- =============================================================================

alter table public.transactions add column if not exists payment_ref text;
alter table public.transactions add column if not exists provider_payment_id text;
alter table public.transactions add column if not exists payment_method text;

create unique index if not exists transactions_payment_ref_key
  on public.transactions (payment_ref) where payment_ref is not null;
create unique index if not exists transactions_provider_payment_id_key
  on public.transactions (provider_payment_id) where provider_payment_id is not null;

-- ── fulfill_ticket_purchase, with payment details ───────────────────────
-- Same behaviour as the 3-argument version (it calls the same
-- _do_ticket_purchase, so stock, the one-ticket-per-day rule, fees and
-- idempotency are unchanged), then records the payment details on the
-- ticket's primary purchase transaction. If verify and the webhook race, or
-- the ticket was issued earlier by a function that did not send details, the
-- first call that carries them fills the empty fields; a value already stored
-- is never overwritten. Only service_role may call it (no grants).
create or replace function public.fulfill_ticket_purchase(
  p_tier_id uuid,
  p_buyer_id uuid,
  p_qr_code_token text,
  p_payment_ref text,
  p_provider_payment_id text,
  p_payment_method text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  v_ticket public.tickets;
  v_ref text := nullif(left(btrim(coalesce(p_payment_ref, '')), 120), '');
  v_provider text := nullif(left(btrim(coalesce(p_provider_payment_id, '')), 120), '');
  v_method text := nullif(left(lower(btrim(coalesce(p_payment_method, ''))), 30), '');
begin
  v_ticket := public._do_ticket_purchase(p_tier_id, p_buyer_id, p_qr_code_token);

  update public.transactions t
     set payment_ref         = coalesce(t.payment_ref, v_ref),
         provider_payment_id = coalesce(t.provider_payment_id, v_provider),
         payment_method      = coalesce(t.payment_method, v_method)
   where t.ticket_id = v_ticket.ticket_id
     and t.transaction_type = 'purchase'
     and t.buyer_id = p_buyer_id
     and (t.payment_ref is null or t.provider_payment_id is null or t.payment_method is null);

  return v_ticket;
end;
$$;

revoke all on function public.fulfill_ticket_purchase(uuid, uuid, text, text, text, text)
  from public, anon, authenticated;
