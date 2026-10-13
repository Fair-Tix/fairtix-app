-- =============================================================================
-- FairTix — checkout guard (server-side purchase limit + server-side price)
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run (create or replace).
--
-- Why this exists:
--   1. The one-ticket-per-account-per-event-day limit used to be checked only
--      in the Flutter app (from a local ticket cache), so a modified app or a
--      stale/offline cache could buy twice. It is now enforced on the server:
--      here BEFORE a payment link is created (paymongo-checkout), and again
--      inside _do_ticket_purchase as a backstop.
--   2. paymongo-checkout used to trust the `amount` the app sent, so someone
--      could send amount = 1 for an expensive tier. The price is now computed
--      here from ticket_tiers.base_price.
--
-- Multi-day events are stored as one sub-event per day (events.parent_event_id),
-- so "per event day" is simply "per events.event_id".
-- =============================================================================

-- ── Has this user already used their ticket slot for this event day? ────
-- True if they currently hold a ticket for it (valid, listed or used), OR
-- they already resold their ticket for it (the slot is not given back).
-- Canceled tickets (event canceled -> refunded) do not count.
create or replace function public.ticket_slot_used(p_user_id uuid, p_event_id uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select
    exists (
      select 1
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      where t.owner_id = p_user_id
        and tt.event_id = p_event_id
        and t.ticket_status <> 'canceled'
    )
    or exists (
      select 1
      from public.transactions tr
      join public.tickets t       on t.ticket_id = tr.ticket_id
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      where tr.transaction_type = 'resale'
        and tr.seller_id = p_user_id
        and tr.status = 'completed'
        and tt.event_id = p_event_id
    );
$$;

revoke all on function public.ticket_slot_used(uuid, uuid) from public, anon, authenticated;

-- ── Quote for a checkout: validates the purchase and returns the price ──
-- Called by the paymongo-checkout Edge Function (service_role) before it
-- creates a PayMongo link. Raises a plain-sentence error if the buyer
-- can't buy; otherwise returns the event id and the amount to charge.
-- The buyer pays exactly the listed ticket price: FairTix's platform fee
-- (8% / 9% / 10% by the organizer's plan, see plan_fee_rate in
-- purchase_functions.sql) is deducted from the organizer's proceeds, not
-- added on top.
create or replace function public.checkout_quote(p_tier_id uuid, p_buyer_id uuid)
returns table (out_event_id uuid, out_amount numeric)
language plpgsql
security definer set search_path = public
as $$
declare
  v_event_id  uuid;
  v_price     numeric(10,2);
  v_remaining int;
  v_status    event_status;
begin
  select tt.event_id, tt.base_price, tt.remaining_quantity, e.status
    into v_event_id, v_price, v_remaining, v_status
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = p_tier_id;

  if not found then
    raise exception 'That ticket tier no longer exists.';
  end if;
  if v_status <> 'published' then
    raise exception 'This event is not open for ticket sales.';
  end if;
  if v_remaining <= 0 then
    raise exception 'This ticket tier is sold out.';
  end if;
  if public.ticket_slot_used(p_buyer_id, v_event_id) then
    raise exception 'You can only hold one ticket per event day. You already have (or have resold) a ticket for this one.';
  end if;

  return query select v_event_id, v_price;
end;
$$;

revoke all on function public.checkout_quote(uuid, uuid) from public, anon, authenticated;
