-- =============================================================================
-- FairTix — account approval + subscription access control (server side).
-- Run AFTER checkout_guard.sql, resale_functions.sql, scanner_functions.sql
-- and organizer_event_functions.sql. Safe to re-run.
--
-- Rules enforced here (the app mirrors them with clear "locked" messages):
--   * Eventgoers can browse any time, but BUYING a ticket (primary checkout
--     and resale checkout) and LISTING a ticket for resale need an account an
--     admin has approved (id_verification_status = 'verified') and that is
--     active. Resale checkout already checked this (resale_payment.sql).
--   * Organizers can browse and view, but creating/editing events (already
--     enforced in create_event_with_days / update_event_details) and starting
--     scanner sessions need (a) admin approval and (b) a current subscription.
--   * An EXPIRED subscription never blocks login or reading; it only locks the
--     subscription features above until the organizer renews.
-- =============================================================================

-- ── Primary ticket checkout: buyer must be approved ─────────────────────
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
  if not exists (
    select 1 from public.users
    where id = p_buyer_id
      and id_verification_status = 'verified'
      and account_status = 'active'
  ) then
    raise exception 'Your account needs to be approved by an admin before you can buy tickets.';
  end if;

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

-- ── Resale listing: seller must be approved ─────────────────────────────
create or replace function public.guard_resale_listing_access()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.users
    where id = new.seller_id
      and id_verification_status = 'verified'
      and account_status = 'active'
  ) then
    raise exception 'Your account needs to be approved by an admin before you can resell tickets.';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_resale_listing_access()
  from public, anon, authenticated;

drop trigger if exists guard_resale_listing_access on public.resale_listings;
create trigger guard_resale_listing_access
  before insert on public.resale_listings
  for each row execute procedure public.guard_resale_listing_access();

-- ── Scanner sessions: organizer must be approved AND subscribed ─────────
create or replace function public.guard_scanner_session_access()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Admins keep their existing access.
  if public.is_admin() then
    return new;
  end if;

  if not exists (
    select 1 from public.users
    where id = new.organizer_id
      and role = 'organizer'
      and id_verification_status = 'verified'
      and account_status = 'active'
  ) then
    raise exception 'Your organizer account needs to be approved by an admin before you can start scanner sessions.';
  end if;

  if (select p.plan_id from public._organizer_plan(new.organizer_id) p) is null then
    raise exception 'Your subscription has expired or is missing. Renew your plan to start scanner sessions.';
  end if;

  return new;
end;
$$;

revoke all on function public.guard_scanner_session_access()
  from public, anon, authenticated;

drop trigger if exists guard_scanner_session_access on public.scanner_sessions;
create trigger guard_scanner_session_access
  before insert on public.scanner_sessions
  for each row execute procedure public.guard_scanner_session_access();

-- Not changed on purpose (already enforced elsewhere):
--   create_event_with_days  -> verified + active + current plan
--   update_event_details    -> current plan
--   resale_checkout_quote   -> buyer verified + active
--   organizer_can_export()  -> current plan with export switch
-- cancel_event stays available to an expired organizer so they can still
-- cancel an event and refund their buyers.
