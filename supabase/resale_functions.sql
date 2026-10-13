-- =============================================================================
-- FairTix — resale listing RPCs
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run (create or replace / drop if exists).
--
-- Why this exists: listing a ticket for resale has to do several things
-- together or not at all — verify the caller owns a valid ticket, enforce
-- the 24-hour cutoff and the 50%-100% price band, create the
-- resale_listings row, and flip tickets.ticket_status to 'listed'.
-- policies.sql deliberately gives buyers no UPDATE on `tickets`, so this has
-- to be a SECURITY DEFINER function (same pattern as the purchase RPCs).
--
-- It also REMOVES the direct client INSERT/UPDATE/DELETE policies on
-- resale_listings that policies.sql created. Those only checked
-- `seller_id = auth.uid()`, so a signed-in user could insert a listing
-- straight into the table and skip every rule below (any price, any
-- ticket). After this file, listings can only be created or cancelled
-- through the two functions here. Reads are unchanged.
-- =============================================================================

-- ── list_ticket_for_resale ──────────────────────────────────────────────
create or replace function public.list_ticket_for_resale(
  p_ticket_id uuid,
  p_price numeric
)
returns public.resale_listings
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_ticket public.tickets;
  v_event_status event_status;
  v_event_start date;
  v_event_title text;
  v_tier_name text;
  v_price numeric(10,2);
  v_floor numeric(10,2);
  v_listing public.resale_listings;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to list a ticket.';
  end if;

  -- Lock the ticket row so two simultaneous requests can't both list it.
  select * into v_ticket
    from public.tickets
    where ticket_id = p_ticket_id
    for update;

  if not found or v_ticket.owner_id <> v_user_id then
    raise exception 'You can only list tickets that you own.';
  end if;

  if v_ticket.ticket_status <> 'valid' or v_ticket.qr_status <> 'active' then
    raise exception 'Only valid, unused tickets can be listed for resale.';
  end if;

  if exists (
    select 1 from public.resale_listings
    where ticket_id = p_ticket_id and listing_status = 'active'
  ) then
    raise exception 'This ticket is already listed for resale.';
  end if;

  select e.status, e.event_start_date, e.title, tt.tier_name
    into v_event_status, v_event_start, v_event_title, v_tier_name
    from public.ticket_tiers tt
    join public.events e on e.event_id = tt.event_id
    where tt.tier_id = v_ticket.tier_id;

  if v_event_status <> 'published' then
    raise exception 'This event is no longer open for resale.';
  end if;

  -- Listings close 24 hours before the event starts. event_start_date is a
  -- plain date, so it is read as midnight Philippine time, which matches how
  -- the app computes the same cutoff on a device in the Philippines.
  if now() > ((v_event_start::timestamp at time zone 'Asia/Manila') - interval '24 hours') then
    raise exception 'Resale listings for this event have closed. They close 24 hours before the event starts.';
  end if;

  v_price := round(p_price, 2);
  v_floor := round(v_ticket.purchase_price * 0.5, 2);
  if v_price is null or v_price < v_floor or v_price > v_ticket.purchase_price then
    raise exception 'Resale price must be between PHP % and PHP % (50%% to 100%% of the original price).',
      v_floor, v_ticket.purchase_price;
  end if;

  insert into public.resale_listings (ticket_id, seller_id, listing_price, listing_status)
  values (p_ticket_id, v_user_id, v_price, 'active')
  returning * into v_listing;

  update public.tickets
    set ticket_status = 'listed'
    where ticket_id = p_ticket_id;

  -- Tell the seller the listing is live (the app also shows a confirmation
  -- screen, but this is the record they can come back to).
  insert into public.notifications (user_id, title, message, type, channel)
  values (
    v_user_id,
    'Ticket Listed for Resale',
    format(
      'Your %s ticket for %s is now listed on the Resale Market for PHP %s. The listing closes automatically 24 hours before the event.',
      v_tier_name, v_event_title, to_char(v_price, 'FM999,999,990.00')
    ),
    'resale', 'in_app'
  );

  return v_listing;
end;
$$;

revoke all on function public.list_ticket_for_resale(uuid, numeric) from public, anon;
grant execute on function public.list_ticket_for_resale(uuid, numeric) to authenticated;

-- ── cancel_resale_listing ───────────────────────────────────────────────
-- Seller takes their ticket back off the market. Keyed on the ticket id
-- (which the app already has) rather than the listing id.
create or replace function public.cancel_resale_listing(p_ticket_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_listing_id uuid;
  v_event_title text;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to cancel a listing.';
  end if;

  select listing_id into v_listing_id
    from public.resale_listings
    where ticket_id = p_ticket_id
      and seller_id = v_user_id
      and listing_status = 'active'
    limit 1
    for update;

  if not found then
    raise exception 'No active listing was found for this ticket.';
  end if;

  update public.resale_listings
    set listing_status = 'canceled'
    where listing_id = v_listing_id;

  update public.tickets
    set ticket_status = 'valid'
    where ticket_id = p_ticket_id
      and owner_id = v_user_id
      and ticket_status = 'listed';

  select e.title into v_event_title
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e        on e.event_id = tt.event_id
    where t.ticket_id = p_ticket_id;

  insert into public.notifications (user_id, title, message, type, channel)
  values (
    v_user_id,
    'Resale Listing Canceled',
    format(
      'You took your ticket for %s off the Resale Market. It is valid again and ready to use.',
      coalesce(v_event_title, 'the event')
    ),
    'resale', 'in_app'
  );
end;
$$;

revoke all on function public.cancel_resale_listing(uuid) from public, anon;
grant execute on function public.cancel_resale_listing(uuid) to authenticated;

-- ── Lock down direct writes to resale_listings ──────────────────────────
drop policy if exists "resale_listings_insert_own" on public.resale_listings;
drop policy if exists "resale_listings_update_own_or_admin" on public.resale_listings;
drop policy if exists "resale_listings_delete_own_or_admin" on public.resale_listings;
drop policy if exists "resale_listings_write_admin_only" on public.resale_listings;

create policy "resale_listings_write_admin_only"
  on public.resale_listings for all
  using (public.is_admin())
  with check (public.is_admin());

-- ── expire_resale_listings ─────────────────────────────────────────────────────────────
-- Manuscript: all active resale listings close automatically 24 hours before
-- an event day starts, and unsold tickets go back to their original owners
-- in a valid, usable state (for multi-day events each day closes on its own,
-- since every day is its own event row).
--
-- list_ticket_for_resale already refuses NEW listings after the cutoff; this
-- closes the ones that were still active when it passed:
--   listing_status -> 'expired'
--   ticket_status  -> 'valid' (only if it is still 'listed')
--   the seller gets an in-app notification
--
-- It takes no input and only touches listings that are genuinely past their
-- cutoff, and running it repeatedly changes nothing, so it is safe for any
-- signed-in user to call. The app calls it whenever the wallet (and the
-- admin resale list) loads. For expiry that does not depend on someone opening
-- the app, also schedule it with pg_cron (see the end of this file).
-- Returns how many listings it expired.
create or replace function public.expire_resale_listings()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  v_count int;
begin
  with due as (
    select rl.listing_id, rl.ticket_id, rl.seller_id, e.title as event_title
    from public.resale_listings rl
    join public.tickets t       on t.ticket_id = rl.ticket_id
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e        on e.event_id = tt.event_id
    where rl.listing_status = 'active'
      -- Same cutoff list_ticket_for_resale uses: event_start_date is a plain
      -- date, read as midnight Philippine time, minus 24 hours.
      and now() > ((e.event_start_date::timestamp at time zone 'Asia/Manila') - interval '24 hours')
    for update of rl
  ),
  expired as (
    update public.resale_listings rl
       set listing_status = 'expired'
      from due
     where rl.listing_id = due.listing_id
    returning rl.ticket_id, rl.seller_id, due.event_title
  ),
  released as (
    update public.tickets t
       set ticket_status = 'valid'
      from expired
     where t.ticket_id = expired.ticket_id
       and t.ticket_status = 'listed'
    returning t.ticket_id
  ),
  notified as (
    insert into public.notifications (user_id, title, message, type, channel)
    select
      expired.seller_id,
      'Resale Listing Expired',
      format(
        'Your resale listing for %s expired because resale closes 24 hours before the event. Your ticket is valid again and ready to use.',
        expired.event_title
      ),
      'resale', 'in_app'
    from expired
    returning notification_id
  )
  select count(*) into v_count from expired;

  return v_count;
end;
$$;

revoke all on function public.expire_resale_listings() from public, anon;
grant execute on function public.expire_resale_listings() to authenticated;

-- OPTIONAL — run it on a schedule so listings expire even if nobody opens the
-- app. Needs the pg_cron extension: Dashboard -> Database -> Extensions ->
-- enable "pg_cron", then run this once (not part of the re-runnable setup
-- above, so it is commented out):
--
--   select cron.schedule(
--     'expire-resale-listings', '*/10 * * * *',
--     $cron$ select public.expire_resale_listings(); $cron$
--   );
--
-- To remove it later:  select cron.unschedule('expire-resale-listings');
