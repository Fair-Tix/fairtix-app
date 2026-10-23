-- =============================================================================
-- FairTix — resale purchases paid through PayMongo
-- Run this in the Supabase SQL Editor AFTER resale_purchase.sql (and the
-- files it depends on). Safe to re-run.
--
-- Until now a resale purchase was simulated: the buyer's app called
-- buy_resale_listing directly and the ticket changed hands without any
-- payment. Resale now works like a primary purchase:
--
--   1. paymongo-checkout (Edge Function) calls resale_checkout_quote to
--      validate the buyer + listing and get the price, then creates a
--      PayMongo Sandbox Checkout Session whose metadata holds
--      { listing_id, buyer_id }.
--   2. The buyer pays on PayMongo's page and is redirected back to the app.
--   3. paymongo-verify (and paymongo-webhook, independently) confirm the
--      session is PAID with PayMongo, then call fulfill_resale_purchase.
--      That moves the ticket, reissues its QR, records the resale
--      transaction and closes the listing, exactly once per payment.
--
-- The old buyer-callable buy_resale_listing is removed below: leaving it would
-- let anyone take a listed ticket without paying.
--
-- FEE MODEL (unchanged): the buyer pays exactly the listing price; FairTix's
-- flat 5% resale fee comes out of the SELLER's proceeds.
-- =============================================================================

-- ── 0. Idempotency key on transactions ──────────────────────────────────
-- paymongo-verify and paymongo-webhook can both fire for the same payment.
-- The PayMongo checkout session id is stored here so the second one finds
-- the first one's transaction and becomes a no-op instead of a double sale.
alter table public.transactions add column if not exists payment_ref text;
create unique index if not exists transactions_payment_ref_key
  on public.transactions (payment_ref) where payment_ref is not null;

-- ── 1. The old free-ticket path goes away ───────────────────────────────
drop function if exists public.buy_resale_listing(uuid);

-- ── 2. Quote: may this buyer buy this listing, and for how much? ────────
-- Called by paymongo-checkout (service_role) BEFORE any payment is created,
-- so a buyer who can't buy never gets charged.
create or replace function public.resale_checkout_quote(p_listing_id uuid, p_buyer_id uuid)
returns table (out_amount numeric)
language plpgsql
security definer set search_path = public
as $$
declare
  v_listing      public.resale_listings;
  v_ticket       public.tickets;
  v_event_id     uuid;
  v_event_status event_status;
  v_event_start  date;
begin
  if not exists (
    select 1 from public.users
    where id = p_buyer_id
      and id_verification_status = 'verified'
      and account_status = 'active'
  ) then
    raise exception 'Your account needs to be verified before you can buy tickets.';
  end if;

  select * into v_listing from public.resale_listings where listing_id = p_listing_id;
  if not found or v_listing.listing_status <> 'active' then
    raise exception 'This listing is no longer available.';
  end if;
  if v_listing.seller_id = p_buyer_id then
    raise exception 'You cannot buy your own listing.';
  end if;

  select * into v_ticket from public.tickets where ticket_id = v_listing.ticket_id;
  if v_ticket.owner_id <> v_listing.seller_id
     or v_ticket.ticket_status <> 'listed'
     or v_ticket.qr_status <> 'active' then
    raise exception 'This listing is no longer available.';
  end if;

  select e.event_id, e.status, e.event_start_date
    into v_event_id, v_event_status, v_event_start
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = v_ticket.tier_id;

  if v_event_status <> 'published' then
    raise exception 'This event is no longer open for resale.';
  end if;
  if now() > ((v_event_start::timestamp at time zone 'Asia/Manila') - interval '24 hours') then
    raise exception 'Resale for this event has closed. It closes 24 hours before the event starts.';
  end if;
  if public.ticket_slot_used(p_buyer_id, v_event_id) then
    raise exception 'You can only hold one ticket per event day. You already have (or have resold) a ticket for this one.';
  end if;

  return query select v_listing.listing_price;
end;
$$;

revoke all on function public.resale_checkout_quote(uuid, uuid) from public, anon, authenticated;

-- ── 3. Fulfil a PAID resale (idempotent per payment) ────────────────────
create or replace function public._do_resale_purchase(
  p_listing_id uuid,
  p_buyer_id uuid,
  p_payment_ref text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  c_resale_fee_rate constant numeric := 0.05;  -- kResaleSellerFeeRate

  v_listing      public.resale_listings;
  v_ticket       public.tickets;
  v_existing_tid uuid;
  v_event_id     uuid;
  v_event_status event_status;
  v_event_start  date;
  v_fee          numeric(10,2);
begin
  -- Serialise everything for this one payment, then check whether it was
  -- already fulfilled (by verify or the webhook, whichever got here first).
  perform pg_advisory_xact_lock(hashtextextended(p_payment_ref, 0));

  select tr.ticket_id into v_existing_tid
    from public.transactions tr
    where tr.payment_ref = p_payment_ref;
  if found then
    select * into v_ticket from public.tickets where ticket_id = v_existing_tid;
    return v_ticket;
  end if;

  -- Lock listing, then ticket (same order as cancel/expire).
  select * into v_listing
    from public.resale_listings
    where listing_id = p_listing_id
    for update;

  if not found or v_listing.listing_status <> 'active' then
    raise exception 'This listing is no longer available.';
  end if;
  if v_listing.seller_id = p_buyer_id then
    raise exception 'You cannot buy your own listing.';
  end if;

  select * into v_ticket
    from public.tickets
    where ticket_id = v_listing.ticket_id
    for update;

  if v_ticket.owner_id <> v_listing.seller_id
     or v_ticket.ticket_status <> 'listed'
     or v_ticket.qr_status <> 'active' then
    raise exception 'This listing is no longer available.';
  end if;

  select e.event_id, e.status, e.event_start_date
    into v_event_id, v_event_status, v_event_start
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = v_ticket.tier_id;

  if v_event_status <> 'published' then
    raise exception 'This event is no longer open for resale.';
  end if;
  if now() > ((v_event_start::timestamp at time zone 'Asia/Manila') - interval '24 hours') then
    raise exception 'Resale for this event has closed. It closes 24 hours before the event starts.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_buyer_id::text || v_event_id::text, 0));
  if public.ticket_slot_used(p_buyer_id, v_event_id) then
    raise exception 'You can only hold one ticket per event day. You already have (or have resold) a ticket for this one.';
  end if;

  v_fee := round(v_listing.listing_price * c_resale_fee_rate, 2);

  -- Ownership moves to the buyer and the QR is reissued in the same update:
  -- the old token (e.g. the seller's screenshot) stops matching at once.
  -- This is done inline rather than through reissue_ticket_qr because that
  -- function checks auth.uid(), and this runs as the service role (no user).
  -- purchase_price stays the ORIGINAL face value (the 50%-100% band is
  -- measured against it).
  update public.tickets
     set owner_id      = p_buyer_id,
         purchased_at  = now(),
         qr_code_token = 'FTX-RS-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 24),
         qr_status     = 'active',
         ticket_status = 'valid',
         used_at       = null
   where ticket_id = v_ticket.ticket_id;

  insert into public.transactions (
    ticket_id, buyer_id, seller_id, transaction_type, amount,
    platform_fee, status, escrow_status, escrow_amount, payment_ref
  )
  values (
    v_ticket.ticket_id, p_buyer_id, v_listing.seller_id, 'resale',
    v_listing.listing_price, v_fee, 'completed', 'released', 0, p_payment_ref
  );

  update public.resale_listings
     set listing_status = 'sold',
         sold_at = now(),
         escrow_status = 'released'
   where listing_id = v_listing.listing_id;

  -- Notifications for both sides come from the existing
  -- trg_notify_transaction trigger when the completed 'resale' row is inserted.

  select * into v_ticket from public.tickets where ticket_id = v_ticket.ticket_id;
  return v_ticket;
end;
$$;

revoke all on function public._do_resale_purchase(uuid, uuid, text) from public, anon, authenticated;

-- Entry point for the Edge Functions (service_role only, like
-- fulfill_ticket_purchase): they take the buyer from the verified payment
-- metadata, never from the client.
create or replace function public.fulfill_resale_purchase(
  p_listing_id uuid,
  p_buyer_id uuid,
  p_payment_ref text
)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
begin
  return public._do_resale_purchase(p_listing_id, p_buyer_id, p_payment_ref);
end;
$$;

revoke all on function public.fulfill_resale_purchase(uuid, uuid, text) from public, anon, authenticated;
