-- =============================================================================
-- FairTix — fraud alerts + the automated Price Flag system
-- Run in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- resale_functions.sql. Safe to re-run.
--
-- What this adds
--   1. public.fraud_alerts — the queue the admin "Fraud Alerts" screen reads.
--   2. A trigger on resale_listings that raises a PRICE FLAG automatically
--      (manuscript: "Automated Price Flag System for exploitative pricing
--      review"). Resale prices are already forced into 50%-100% of the
--      original price by list_ticket_for_resale, so "exploitative" here
--      cannot mean "above face value". The rules below are an interpretation
--      of what is still worth a human look:
--        near_floor_price  price is at or below 60% of the original. The 50%
--                          floor exists to stop nominal-price transfers that
--                          dodge the one-ticket-per-account limit, so
--                          listings hugging the floor are the suspicious ones.
--                          55% or lower is rated high severity, otherwise
--                          medium.
--        rapid_relist      the same seller listed the same ticket 3 or more
--                          times in 24 hours (cancel / relist churn), rated
--                          low severity.
--      Change the three constants at the top of flag_resale_listing() to
--      tune them; nothing else needs to change.
--   3. admin_update_fraud_alert()    — review / resolve / dismiss an alert.
--   4. admin_remove_resale_listing() — admin takes a listing off the market
--      (ticket goes back to valid, seller is notified).
--
-- Alerts are only ever created by the trigger / this file (no client insert
-- policy), and only changed through admin_update_fraud_alert. Organizers
-- cannot flag a listing from the app yet, so source = 'organizer' is
-- reserved for when that exists.
-- =============================================================================

create table if not exists public.fraud_alerts (
  alert_id        uuid primary key default gen_random_uuid(),
  alert_type      text not null
                    check (alert_type in ('near_floor_price', 'rapid_relist', 'organizer_report')),
  source          text not null default 'system'
                    check (source in ('system', 'organizer')),
  severity        text not null default 'medium'
                    check (severity in ('low', 'medium', 'high')),
  status          text not null default 'open'
                    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  user_id         uuid references public.users(id),
  event_id        uuid references public.events(event_id),
  ticket_id       uuid references public.tickets(ticket_id),
  listing_id      uuid references public.resale_listings(listing_id),
  details         text not null,
  created_at      timestamptz not null default now(),
  -- Who reviewed it. Plain uuid on purpose (no foreign key), so the table has
  -- a single relationship to public.users and the app can embed the flagged
  -- user without naming a constraint.
  reviewed_by     uuid,
  reviewed_at     timestamptz,
  resolution_note text
);

-- One alert per (type, listing), so re-running the backfill or a retried
-- insert can never duplicate an alert. NULL listing ids are all distinct.
create unique index if not exists fraud_alerts_type_listing_uidx
  on public.fraud_alerts (alert_type, listing_id);
create index if not exists fraud_alerts_status_idx on public.fraud_alerts (status);
create index if not exists fraud_alerts_created_idx on public.fraud_alerts (created_at desc);

alter table public.fraud_alerts enable row level security;

drop policy if exists "fraud_alerts_select_admin" on public.fraud_alerts;
create policy "fraud_alerts_select_admin"
  on public.fraud_alerts for select
  using (public.is_admin());
-- No insert / update / delete policy: the trigger below (SECURITY DEFINER)
-- creates alerts and admin_update_fraud_alert changes them.

-- ── Automatic price flags ───────────────────────────────────────────────
create or replace function public.flag_resale_listing()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  -- ── Tuning knobs ──
  c_near_floor   constant numeric := 0.60;  -- flag at or below 60% of original
  c_high         constant numeric := 0.55;  -- ...rated high at or below 55%
  c_relist_count constant int     := 3;     -- relistings within 24h to flag

  v_original numeric(10,2);
  v_event_id uuid;
  v_title    text;
  v_recent   int;
begin
  select t.purchase_price, tt.event_id, e.title
    into v_original, v_event_id, v_title
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  if v_original is null or v_original <= 0 then
    return new;
  end if;

  if new.listing_price <= v_original * c_near_floor then
    insert into public.fraud_alerts
      (alert_type, source, severity, user_id, event_id, ticket_id, listing_id, details)
    values (
      'near_floor_price', 'system',
      case when new.listing_price <= v_original * c_high then 'high' else 'medium' end,
      new.seller_id, v_event_id, new.ticket_id, new.listing_id,
      format(
        'Listed at PHP %s (%s%% of the PHP %s original) for %s. Prices close to the 50%% floor can mean a nominal-price transfer used to get around the one-ticket-per-account limit.',
        to_char(new.listing_price, 'FM999,999,990.00'),
        round(new.listing_price / v_original * 100),
        to_char(v_original, 'FM999,999,990.00'),
        v_title
      )
    )
    on conflict (alert_type, listing_id) do nothing;
  end if;

  select count(*) into v_recent
    from public.resale_listings
    where seller_id = new.seller_id
      and ticket_id = new.ticket_id
      and listed_at > now() - interval '24 hours';

  if v_recent >= c_relist_count then
    insert into public.fraud_alerts
      (alert_type, source, severity, user_id, event_id, ticket_id, listing_id, details)
    values (
      'rapid_relist', 'system', 'low',
      new.seller_id, v_event_id, new.ticket_id, new.listing_id,
      format(
        'The same ticket for %s has been listed %s times in the last 24 hours (list / cancel / relist).',
        v_title, v_recent
      )
    )
    on conflict (alert_type, listing_id) do nothing;
  end if;

  return new;
end;
$$;

revoke all on function public.flag_resale_listing() from public, anon, authenticated;

drop trigger if exists on_resale_listing_flag on public.resale_listings;
create trigger on_resale_listing_flag
  after insert on public.resale_listings
  for each row execute procedure public.flag_resale_listing();

-- ── Backfill: flag listings that already exist ──────────────────────────
-- Same near-floor rule as the trigger (60% / 55%). Skip if you have no
-- listings yet. Safe to re-run.
insert into public.fraud_alerts
  (alert_type, source, severity, user_id, event_id, ticket_id, listing_id, details, created_at)
select
  'near_floor_price', 'system',
  case when rl.listing_price <= t.purchase_price * 0.55 then 'high' else 'medium' end,
  rl.seller_id, tt.event_id, rl.ticket_id, rl.listing_id,
  format(
    'Listed at PHP %s (%s%% of the PHP %s original) for %s. Prices close to the 50%% floor can mean a nominal-price transfer used to get around the one-ticket-per-account limit.',
    to_char(rl.listing_price, 'FM999,999,990.00'),
    round(rl.listing_price / t.purchase_price * 100),
    to_char(t.purchase_price, 'FM999,999,990.00'),
    e.title
  ),
  rl.listed_at
from public.resale_listings rl
join public.tickets t       on t.ticket_id = rl.ticket_id
join public.ticket_tiers tt on tt.tier_id = t.tier_id
join public.events e        on e.event_id = tt.event_id
where t.purchase_price > 0
  and rl.listing_price <= t.purchase_price * 0.60
on conflict (alert_type, listing_id) do nothing;

-- ── Admin: review an alert ──────────────────────────────────────────────
create or replace function public.admin_update_fraud_alert(
  p_alert_id uuid,
  p_status   text,
  p_note     text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can review fraud alerts.';
  end if;
  if p_status not in ('open', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Unknown alert status.';
  end if;

  update public.fraud_alerts
     set status          = p_status,
         reviewed_by     = auth.uid(),
         reviewed_at     = now(),
         resolution_note = coalesce(nullif(trim(p_note), ''), resolution_note)
   where alert_id = p_alert_id;

  if not found then
    raise exception 'Alert not found.';
  end if;
end;
$$;

revoke all on function public.admin_update_fraud_alert(uuid, text, text) from public, anon;
grant execute on function public.admin_update_fraud_alert(uuid, text, text) to authenticated;

-- ── Admin: take a resale listing off the market ─────────────────────────
create or replace function public.admin_remove_resale_listing(
  p_listing_id uuid,
  p_reason     text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_ticket_id uuid;
  v_seller_id uuid;
  v_title     text;
begin
  if not public.is_admin() then
    raise exception 'Only admins can remove resale listings.';
  end if;

  select rl.ticket_id, rl.seller_id
    into v_ticket_id, v_seller_id
    from public.resale_listings rl
    where rl.listing_id = p_listing_id and rl.listing_status = 'active'
    for update;

  if not found then
    raise exception 'That listing was not found or is no longer active.';
  end if;

  update public.resale_listings
     set listing_status = 'canceled'
   where listing_id = p_listing_id;

  -- Back to a normal, usable ticket in the seller's wallet.
  update public.tickets
     set ticket_status = 'valid'
   where ticket_id = v_ticket_id and ticket_status = 'listed';

  select e.title into v_title
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = v_ticket_id;

  insert into public.notifications (user_id, title, message, type, channel)
  values (
    v_seller_id,
    'Resale Listing Removed',
    format(
      'An administrator removed your resale listing for %s%s. Your ticket is valid again.',
      coalesce(v_title, 'the event'),
      case when coalesce(trim(p_reason), '') <> '' then ': ' || trim(p_reason) else '' end
    ),
    'resale', 'in_app'
  );
end;
$$;

revoke all on function public.admin_remove_resale_listing(uuid, text) from public, anon;
grant execute on function public.admin_remove_resale_listing(uuid, text) to authenticated;
