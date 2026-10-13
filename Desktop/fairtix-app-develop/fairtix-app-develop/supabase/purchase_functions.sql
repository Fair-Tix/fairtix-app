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
  select remaining_quantity, base_price
    into v_remaining, v_base_price
    from public.ticket_tiers
    where tier_id = p_tier_id
    for update;

  if not found then
    raise exception 'That ticket tier no longer exists.';
  end if;
  if v_remaining <= 0 then
    raise exception 'This ticket tier is sold out.';
  end if;

  -- Mirrors kPrimaryPlatformFeeRate (10%%) in lib/models/event.dart.
  v_service_fee := round(v_base_price * 0.10, 2);

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
    v_base_price + v_service_fee, v_service_fee, 'completed', 'released', 0
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
create or replace function public.purchase_ticket(
  p_tier_id uuid,
  p_qr_code_token text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  v_buyer_id uuid := auth.uid();
begin
  if v_buyer_id is null then
    raise exception 'You need to be signed in to purchase a ticket.';
  end if;
  return public._do_ticket_purchase(p_tier_id, v_buyer_id, p_qr_code_token);
end;
$$;

grant execute on function public.purchase_ticket(uuid, text) to authenticated;

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
