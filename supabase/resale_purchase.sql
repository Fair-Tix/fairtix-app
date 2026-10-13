-- =============================================================================
-- FairTix — resale market + resale purchase
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- purchase_functions.sql, scanner_functions.sql (reissue_ticket_qr),
-- checkout_guard.sql (ticket_slot_used), security_patch.sql and
-- resale_functions.sql. Safe to re-run (create or replace).
--
-- Adds two functions:
--
--   get_resale_market()        what the Resale Market tab lists: other users'
--                              active listings. The app cannot read another
--                              person's ticket row (tickets RLS is owner /
--                              organizer / admin only), so this joins it for
--                              them and returns only what a buyer may see.
--                              It deliberately does NOT return qr_code_token.
--
--   buy_resale_listing(id)     buys one listing. In a single transaction:
--                                1. checks the buyer and the listing,
--                                2. moves the ticket to the buyer,
--                                3. calls reissue_ticket_qr so the seller's
--                                   QR (e.g. a screenshot) stops working,
--                                4. records the 'resale' transaction,
--                                5. marks the listing sold,
--                                6. notifies the seller and the buyer.
--
-- Why it calls reissue_ticket_qr from here: security_patch.sql revoked that
-- function from ticket owners (it resets a ticket to valid/active, so an
-- owner could use it to revive a scanned ticket). This function is SECURITY
-- DEFINER, so it runs as the table owner and still may call it. The ticket is
-- moved to the buyer FIRST, because reissue_ticket_qr only acts on a ticket
-- the caller owns, and the caller is the buyer.
--
-- FEE MODEL (matches the rest of the project): the buyer pays exactly the
-- listing price. FairTix keeps a flat 5% resale fee, taken out of the
-- SELLER's proceeds: transactions.amount = listing price,
-- transactions.platform_fee = 5% of it, seller receives the difference.
--
-- PAYMENT: like the Resale Checkout screen says, resale payment is simulated
-- (no real money moves). That means any verified signed-in user can call
-- buy_resale_listing and take a listed ticket without paying. This is fine
-- for the sandbox/demo scope, but before real money is involved, resale must
-- go through a verified PayMongo payment the way primary purchases do
-- (paymongo-checkout / paymongo-verify), with this function becoming
-- service-role only.
-- =============================================================================

-- ── get_resale_market ───────────────────────────────────────────────────
create or replace function public.get_resale_market()
returns table (
  listing_id      uuid,
  ticket_id       uuid,
  listing_price   numeric,
  original_price  numeric,
  seller_name     text,
  tier_id         uuid,
  tier_name       text,
  tier_price      numeric,
  event_id        uuid,
  event_title     text,
  venue           text,
  event_start_date date,
  event_end_date  date,
  event_type      text
)
language sql stable
security definer set search_path = public
as $$
  select
    rl.listing_id,
    rl.ticket_id,
    rl.listing_price,
    t.purchase_price,
    -- First name only: enough to read "Sold by Maria", not enough to
    -- identify someone to every other user.
    coalesce(nullif(split_part(trim(u.full_name), ' ', 1), ''), 'A verified seller'),
    tt.tier_id,
    tt.tier_name,
    tt.base_price,
    e.event_id,
    e.title,
    e.venue,
    e.event_start_date,
    e.event_end_date,
    e.event_type::text
  from public.resale_listings rl
  join public.tickets t       on t.ticket_id = rl.ticket_id
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e        on e.event_id = tt.event_id
  join public.users u         on u.id = rl.seller_id
  where auth.uid() is not null
    and rl.listing_status = 'active'
    and rl.seller_id <> auth.uid()
    and t.ticket_status = 'listed'
    and e.status = 'published'
    -- Same cutoff as list_ticket_for_resale / expire_resale_listings.
    and now() <= ((e.event_start_date::timestamp at time zone 'Asia/Manila') - interval '24 hours')
  order by rl.listed_at desc;
$$;

revoke all on function public.get_resale_market() from public, anon;
grant execute on function public.get_resale_market() to authenticated;

-- ── buy_resale_listing ──────────────────────────────────────────────────
create or replace function public.buy_resale_listing(p_listing_id uuid)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  -- FairTix's flat resale fee, taken from the seller (kResaleSellerFeeRate
  -- in lib/models/event.dart).
  c_resale_fee_rate constant numeric := 0.05;

  v_buyer_id     uuid := auth.uid();
  v_listing      public.resale_listings;
  v_ticket       public.tickets;
  v_event_id     uuid;
  v_event_title  text;
  v_event_status event_status;
  v_event_start  date;
  v_tier_name    text;
  v_fee          numeric(10,2);
begin
  if v_buyer_id is null then
    raise exception 'You need to be signed in to buy a ticket.';
  end if;

  if not exists (
    select 1 from public.users
    where id = v_buyer_id
      and id_verification_status = 'verified'
      and account_status = 'active'
  ) then
    raise exception 'Your account needs to be verified before you can buy tickets.';
  end if;

  -- Lock the listing first, then the ticket (same order cancel_resale_listing
  -- and expire_resale_listings use), so a simultaneous cancel / second buyer
  -- waits instead of racing.
  select * into v_listing
    from public.resale_listings
    where listing_id = p_listing_id
    for update;

  if not found or v_listing.listing_status <> 'active' then
    raise exception 'This listing is no longer available.';
  end if;

  if v_listing.seller_id = v_buyer_id then
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

  select e.event_id, e.title, e.status, e.event_start_date, tt.tier_name
    into v_event_id, v_event_title, v_event_status, v_event_start, v_tier_name
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = v_ticket.tier_id;

  if v_event_status <> 'published' then
    raise exception 'This event is no longer open for resale.';
  end if;

  if now() > ((v_event_start::timestamp at time zone 'Asia/Manila') - interval '24 hours') then
    raise exception 'Resale for this event has closed. It closes 24 hours before the event starts.';
  end if;

  -- One ticket per account per event day, resold tickets included. Same lock
  -- and check as _do_ticket_purchase, so a primary purchase and a resale
  -- purchase by the same buyer for the same event can't both slip through.
  perform pg_advisory_xact_lock(hashtextextended(v_buyer_id::text || v_event_id::text, 0));

  if public.ticket_slot_used(v_buyer_id, v_event_id) then
    raise exception 'You can only hold one ticket per event day. You already have (or have resold) a ticket for this one.';
  end if;

  v_fee := round(v_listing.listing_price * c_resale_fee_rate, 2);

  -- 1. Ownership moves to the buyer. purchase_price stays the ORIGINAL face
  --    value on purpose: the 50%-100% resale band is measured against it, and
  --    letting it shrink to the resale price would let the band compound
  --    downward on every resale. purchased_at is bumped so the ticket shows
  --    up at the top of the buyer's wallet.
  update public.tickets
     set owner_id = v_buyer_id,
         purchased_at = now()
   where ticket_id = v_ticket.ticket_id;

  -- 2. Fresh QR token, status valid/active. The old token stops matching.
  --    Allowed here even though owners can't call it directly (see header).
  perform public.reissue_ticket_qr(v_ticket.ticket_id);

  -- 3. The resale transaction. Escrow is recorded as released since there is
  --    no real payment to hold (see PAYMENT in the header).
  insert into public.transactions (
    ticket_id, buyer_id, seller_id, transaction_type, amount,
    platform_fee, status, escrow_status, escrow_amount
  )
  values (
    v_ticket.ticket_id, v_buyer_id, v_listing.seller_id, 'resale',
    v_listing.listing_price, v_fee, 'completed', 'released', 0
  );

  -- 4. Close the listing.
  update public.resale_listings
     set listing_status = 'sold',
         sold_at = now(),
         escrow_status = 'released'
   where listing_id = v_listing.listing_id;

  -- 5. Tell both sides.
  insert into public.notifications (user_id, title, message, type, channel)
  values
    (
      v_listing.seller_id,
      'Ticket Sold',
      format(
        'Your %s ticket for %s sold for PHP %s. After FairTix''s 5%% resale fee you receive PHP %s. The QR code has moved to the buyer.',
        v_tier_name, v_event_title,
        to_char(v_listing.listing_price, 'FM999,999,990.00'),
        to_char(v_listing.listing_price - v_fee, 'FM999,999,990.00')
      ),
      'resale', 'in_app'
    ),
    (
      v_buyer_id,
      'Resale Ticket Purchased',
      format(
        'You bought a %s ticket for %s for PHP %s. It is in your wallet with a new QR code.',
        v_tier_name, v_event_title,
        to_char(v_listing.listing_price, 'FM999,999,990.00')
      ),
      'resale', 'in_app'
    );

  select * into v_ticket from public.tickets where ticket_id = v_ticket.ticket_id;
  return v_ticket;
end;
$$;

revoke all on function public.buy_resale_listing(uuid) from public, anon;
grant execute on function public.buy_resale_listing(uuid) to authenticated;
