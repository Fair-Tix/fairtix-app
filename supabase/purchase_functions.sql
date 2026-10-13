-- =============================================================================
-- FairTix — ticket purchase RPCs
-- Run this in the Supabase SQL Editor AFTER schema.sql and policies.sql.
-- Supersedes the earlier version of this file (adds idempotent fulfillment
-- shared by both the client-side confirm tap and the paymongo-webhook
-- Edge Function, keyed on the PayMongo Payment Link id).
--
-- Why this exists: policies.sql intentionally does NOT let a buyer UPDATE
-- `ticket_tiers` directly (that's owning-organizer/admin only, so a buyer
-- can't tamper with price/quantity). A real purchase needs to atomically:
-- check stock, insert the ticket, insert the transaction, and decrement
-- remaining_quantity — all-or-nothing. A SECURITY DEFINER function is the
-- sanctioned way to do that, same pattern as `handle_new_auth_user` in
-- schema.sql.
--
-- Two fulfillment paths call into the same core logic, keyed on the same
-- deterministic qr_code_token ('FTX-<paymongo_link_id>'):
--   1. purchase_ticket        — called by the signed-in buyer's own client
--      right after they tap "I've Completed Payment" (fast path; works
--      even before the webhook below is deployed).
--   2. fulfill_ticket_purchase — called by the paymongo-webhook Edge
--      Function (service_role) when PayMongo itself confirms the payment
--      server-to-server (the authoritative path).
-- Because both derive the same token from the same link id, whichever
-- fires first wins and the second becomes a no-op that just returns the
-- already-created ticket — no double-issuance if both happen to fire.
-- =============================================================================

-- ── Fee rate by organizer plan ───────────────────────────────────────────
-- FairTix's primary-sale platform fee depends on the ORGANIZER's plan
-- (organizer-subscription-plan.dart):
--   Basic    (monthly_fee 299)  -> 8%
--   Standard (monthly_fee 699)  -> 9%
--   Premium  (monthly_fee 1499) -> 10%
-- organizer_subscriptions has no plan-name column (only monthly_fee), so the
-- plan is derived from the fee, the same mapping the Flutter app uses.
--
-- FEE MODEL: the buyer pays exactly the listed ticket price. The platform fee
-- is taken OUT of the organizer's proceeds, never added on top for the buyer
-- ("buyers are never charged more than the ticket tier price" - Definition of
-- Terms, Platform Fee). So for a primary purchase:
--   transactions.amount       = ticket price (what the buyer paid)
--   transactions.platform_fee = price x plan rate (FairTix's cut)
--   organizer receives        = amount - platform_fee
create or replace function public.plan_fee_rate(p_monthly_fee numeric)
returns numeric
language sql immutable
as $$
  select case p_monthly_fee
    when 299  then 0.08
    when 699  then 0.09
    when 1499 then 0.10
    else 0.10  -- no active plan / unknown fee: fall back to the highest rate
  end;
$$;

-- The rate that applies to this organizer's sales right now (their latest
-- active subscription). Internal: only called from the purchase functions.
create or replace function public.organizer_fee_rate(p_organizer_id uuid)
returns numeric
language sql stable
security definer set search_path = public
as $$
  select public.plan_fee_rate((
    select s.monthly_fee
    from public.organizer_subscriptions s
    where s.user_id = p_organizer_id and s.status = 'active'
    order by s.start_date desc, s.created_at desc
    limit 1
  ));
$$;

revoke all on function public.organizer_fee_rate(uuid) from public, anon, authenticated;

create or replace function public._do_ticket_purchase(
  p_tier_id uuid,
  p_buyer_id uuid,
  p_qr_code_token text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  v_remaining int;
  v_event_id uuid;
  v_organizer_id uuid;
  v_base_price numeric(10,2);
  v_service_fee numeric(10,2);
  v_ticket public.tickets;
  v_existing public.tickets;
begin
  -- Idempotency: if this exact payment (link id) was already fulfilled by
  -- the other path, hand back the ticket that was already created instead
  -- of erroring or issuing a second one.
  select * into v_existing from public.tickets where qr_code_token = p_qr_code_token;
  if found then
    return v_existing;
  end if;

  -- Lock the tier row so two concurrent purchases can't both read the same
  -- remaining_quantity and oversell the last ticket.
  select tt.remaining_quantity, tt.base_price, tt.event_id, e.organizer_id
    into v_remaining, v_base_price, v_event_id, v_organizer_id
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = p_tier_id
    for update of tt;

  if not found then
    raise exception 'That ticket tier no longer exists.';
  end if;
  if v_remaining <= 0 then
    raise exception 'This ticket tier is sold out.';
  end if;

  -- One ticket per account per event day (see checkout_guard.sql). The
  -- checkout function already checks this BEFORE taking payment; this is the
  -- backstop for two checkouts racing. The advisory lock makes simultaneous
  -- purchases by the same buyer for the same event run one after another, so
  -- the second one sees the first one's ticket.
  perform pg_advisory_xact_lock(hashtextextended(p_buyer_id::text || v_event_id::text, 0));

  -- Re-check idempotency now that we hold the locks: if verify and the webhook
  -- raced on the SAME payment, the other one has just created this ticket, so
  -- return it instead of tripping the limit check below on our own twin.
  select * into v_existing from public.tickets where qr_code_token = p_qr_code_token;
  if found then
    return v_existing;
  end if;

  if public.ticket_slot_used(p_buyer_id, v_event_id) then
    raise exception 'You already hold (or have resold) a ticket for this event day.';
  end if;

  -- FairTix's cut, by the organizer's plan (8% / 9% / 10%). It comes out of
  -- the organizer's proceeds; the buyer pays only the listed price. Mirrors
  -- plan_fee_rate above and the plan fees in organizer-subscription-plan.dart.
  v_service_fee := round(v_base_price * public.organizer_fee_rate(v_organizer_id), 2);

  begin
    insert into public.tickets (
      tier_id, owner_id, qr_code_token, qr_status, ticket_status,
      purchase_price, service_fee, purchased_at
    )
    values (
      p_tier_id, p_buyer_id, p_qr_code_token, 'active', 'valid',
      v_base_price, v_service_fee, now()
    )
    returning * into v_ticket;
  exception when unique_violation then
    -- Lost a race with the other fulfillment path between our check above
    -- and this insert — fetch and return what it created.
    select * into v_ticket from public.tickets where qr_code_token = p_qr_code_token;
    return v_ticket;
  end;

  insert into public.transactions (
    ticket_id, buyer_id, seller_id, transaction_type, amount,
    platform_fee, status, escrow_status, escrow_amount
  )
  values (
    v_ticket.ticket_id, p_buyer_id, null, 'purchase',
    v_base_price, v_service_fee, 'completed', 'released', 0
  );

  update public.ticket_tiers
    set remaining_quantity = remaining_quantity - 1
    where tier_id = p_tier_id;

  return v_ticket;
end;
$$;

-- Nobody calls the shared helper directly — only through the two entry
-- points below, which apply the appropriate identity/authorization check.
revoke all on function public._do_ticket_purchase(uuid, uuid, text) from public, anon, authenticated;

-- ── Entry point 1: called by the buyer's own signed-in client ───────────
-- NOTE: purchase_ticket (the old buyer-callable entry point) has been
-- REMOVED. It minted a ticket without checking that a payment happened,
-- so a failed/canceled payment (or a direct RPC call) still produced a
-- ticket. Tickets are now issued only through fulfill_ticket_purchase,
-- called server-side by the paymongo-verify / paymongo-webhook Edge
-- Functions after PayMongo itself confirms the link is paid.
drop function if exists public.purchase_ticket(uuid, text);

-- ── Entry point 2: called by the paymongo-webhook Edge Function only ────
-- Takes buyer_id explicitly since a webhook call has no user session/JWT
-- to read auth.uid() from — it's PayMongo's server calling ours, not the
-- buyer's browser. Only the service_role key (never exposed to the
-- Flutter app) can invoke this, since it's revoked from anon/authenticated
-- below.
create or replace function public.fulfill_ticket_purchase(
  p_tier_id uuid,
  p_buyer_id uuid,
  p_qr_code_token text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
begin
  return public._do_ticket_purchase(p_tier_id, p_buyer_id, p_qr_code_token);
end;
$$;

revoke all on function public.fulfill_ticket_purchase(uuid, uuid, text) from public, anon, authenticated;
-- Deliberately no "grant ... to service_role" line: Supabase's service_role
-- Postgres role bypasses RLS and schema privileges by default, so it can
-- already call this. The two revokes above are what actually matter — they
-- ensure a regular signed-in user (authenticated) or anonymous caller
-- cannot invoke this function and mint themselves a free ticket by passing
-- an arbitrary p_buyer_id.
