-- =============================================================================
-- FairTix - organizer escrow view + "release only after the event date".
-- Run AFTER escrow_and_summary.sql (and the files it needs). Safe to re-run.
--
-- The flow this file enforces and exposes:
--   1. A buyer pays for a ticket        -> the organizer's share is HELD in
--                                          escrow (trigger from
--                                          escrow_and_summary.sql).
--   2. The event takes place            -> still HELD. Scanning a ticket at the
--                                          door no longer releases anything.
--   3. The schedule date is over        -> complete_finished_events() runs once
--                                          the day after the event's LAST day
--                                          starts (Asia/Manila) and RELEASES
--                                          the escrow for payout to the
--                                          organizer (no-shows included).
--   4. The event is canceled            -> the held amount is REFUNDED to the
--                                          buyers instead (refund_functions.sql).
--
-- Money model: PayMongo settles into the FairTix merchant account, so
-- "released" means "now owed to the organizer and ready to be paid out". This
-- app only tracks that ledger; it does not transfer money itself.
--
-- 1. guard_escrow_release: scan_ticket (scanner_functions.sql) still tries to
--    flip escrow to 'released' on an accepted scan. This trigger turns that
--    into a no-op until the ticket's event day is over, so the rule holds even
--    if scanner_functions.sql is re-run later. It compares DATES, not the
--    event status, so it also behaves correctly inside
--    complete_finished_events (which updates the event and the escrow in one
--    statement).
-- 2. One-time fix: escrow that an earlier scan released while the event was
--    still ahead or in progress is put back to 'held'.
-- 3. organizer_escrow_overview(): one row per event of the signed-in organizer
--    for the Escrow screen.
-- =============================================================================

-- ── 1. Block early release ───────────────────────────────────────────────
create or replace function public.guard_escrow_release()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_day date;
  v_today    date := (now() at time zone 'Asia/Manila')::date;
begin
  if old.escrow_status::text = 'held'
     and new.escrow_status::text = 'released'
     and new.transaction_type::text = 'purchase'
     and old.amount > 0 then

    -- Last day of the event this ticket is for. A generated day of a
    -- multi-day run has no end date, so its own start date is its last day.
    select coalesce(e.event_end_date, e.event_start_date)
      into v_last_day
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e on e.event_id = tt.event_id
     where t.ticket_id = new.ticket_id;

    -- Event not over yet (today still counts as an event day): keep it held.
    if v_last_day is not null and v_last_day >= v_today then
      new.escrow_status := old.escrow_status;
    end if;
  end if;
  return new;
end;
$$;

-- Trigger names fire alphabetically; this must run BEFORE trg_settle_escrow,
-- which zeroes escrow_amount when the status becomes 'released'.
drop trigger if exists trg_a_guard_escrow_release on public.transactions;
create trigger trg_a_guard_escrow_release
  before update of escrow_status on public.transactions
  for each row execute procedure public.guard_escrow_release();

-- ── 2. Put back escrow that a scan released too early ────────────────────
update public.transactions tr
   set escrow_status     = 'held',
       escrow_amount     = tr.amount,
       escrow_settled_at = null
  from public.tickets t
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e on e.event_id = tt.event_id
 where t.ticket_id = tr.ticket_id
   and tr.transaction_type::text = 'purchase'
   and tr.status::text = 'completed'
   and tr.escrow_status::text = 'released'
   and tr.amount > 0
   and e.status::text in ('published', 'draft')
   and coalesce(e.event_end_date, e.event_start_date)
         >= (now() at time zone 'Asia/Manila')::date;

-- ── 3. Organizer escrow overview ─────────────────────────────────────────
-- One row per event the signed-in organizer owns (multi-day runs are rolled up
-- under their parent, like the other organizer reports; drafts are skipped).
-- All money is the ORGANIZER'S share: ticket price minus FairTix's fee.
--   escrow_held      still in escrow
--   escrow_released  released for payout
--   refunded_amount  what buyers paid for tickets that were refunded (event
--                    canceled); never counted as held or released
--   release_date     the day escrow is released: the day after the last event
--                    day (Asia/Manila)
-- A ticket whose event was canceled counts as refunded even if it had been
-- resold, so it is never reported as a sale (same rule as get_event_summary).
create or replace function public.organizer_escrow_overview()
returns table (
  event_id         uuid,
  event_title      text,
  event_status     text,
  event_start_date date,
  event_end_date   date,
  release_date     date,
  tickets_sold     integer,
  gross_amount     numeric,
  platform_fees    numeric,
  net_amount       numeric,
  escrow_held      numeric,
  escrow_released  numeric,
  refunded_tickets integer,
  refunded_amount  numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with roots as (
    select r.event_id, r.title, r.status, r.event_start_date, r.event_end_date
      from public.events r
     where r.organizer_id = auth.uid()
       and r.parent_event_id is null
       and r.status::text <> 'draft'
  ),
  scope as (
    select r.event_id as root_id, e.event_id as scoped_id
      from roots r
      join public.events e
        on e.event_id = r.event_id or e.parent_event_id = r.event_id
  ),
  purchases as (
    select s.root_id,
           tr.amount,
           tr.platform_fee,
           case when t.ticket_status::text = 'canceled' then 'refunded'
                else tr.status::text end as pstatus,
           tr.escrow_status::text        as pescrow
      from scope s
      join public.ticket_tiers tt on tt.event_id = s.scoped_id
      join public.tickets t       on t.tier_id = tt.tier_id
      join public.transactions tr on tr.ticket_id = t.ticket_id
     where tr.transaction_type::text = 'purchase'
       and tr.status::text in ('completed', 'refunded')
  )
  select
    r.event_id,
    r.title,
    r.status::text,
    r.event_start_date,
    coalesce(r.event_end_date, r.event_start_date),
    coalesce(r.event_end_date, r.event_start_date) + 1,
    (count(*) filter (where p.pstatus = 'completed'))::integer,
    coalesce(sum(p.amount) filter (where p.pstatus = 'completed'), 0),
    coalesce(sum(p.platform_fee) filter (where p.pstatus = 'completed'), 0),
    coalesce(sum(p.amount - p.platform_fee) filter (where p.pstatus = 'completed'), 0),
    coalesce(sum(p.amount - p.platform_fee)
      filter (where p.pstatus = 'completed' and p.pescrow = 'held'), 0),
    coalesce(sum(p.amount - p.platform_fee)
      filter (where p.pstatus = 'completed' and p.pescrow = 'released'), 0),
    (count(*) filter (where p.pstatus = 'refunded'))::integer,
    coalesce(sum(p.amount) filter (where p.pstatus = 'refunded'), 0)
  from roots r
  left join purchases p on p.root_id = r.event_id
  group by r.event_id, r.title, r.status, r.event_start_date, r.event_end_date
  order by r.event_start_date desc, r.title;
$$;

revoke all on function public.organizer_escrow_overview() from public, anon;
grant execute on function public.organizer_escrow_overview() to authenticated;

-- ── Quick check you can run in the SQL Editor any time ───────────────────
-- Where is all the money right now? (primary ticket purchases only)
--   select escrow_status, count(*) as tickets, sum(amount) as total
--     from public.transactions
--    where transaction_type = 'purchase' and status = 'completed'
--    group by escrow_status;
-- Expect: tickets for upcoming / in-progress events = 'held'; tickets for
-- events whose last day has passed = 'released'; free tickets = 'released'.
