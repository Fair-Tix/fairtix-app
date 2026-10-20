-- =============================================================================
-- FairTix — real escrow tracking + corrected event summary.
-- Run AFTER purchase_functions.sql, scanner_functions.sql, refund_functions.sql
-- and event_completion.sql. Safe to re-run.
--
-- WHY: _do_ticket_purchase recorded every primary purchase as
-- escrow_status = 'released' / escrow_amount = 0, so scan_ticket's release
-- (which only acts on 'held') never matched anything. Escrow was never
-- actually held. This file fixes that WITHOUT rewriting the purchase function:
--
--   1. A BEFORE INSERT trigger on transactions marks a paid primary purchase
--      as 'held' with escrow_amount = amount (free tickets: released at once).
--   2. A BEFORE UPDATE trigger zeroes escrow_amount and stamps
--      escrow_settled_at whenever escrow becomes 'released' or 'refunded'
--      (covers scan_ticket and admin_process_refund unchanged).
--   3. complete_finished_events() now also releases whatever is still held
--      for the events it just completed (no-shows), as the proposal says.
--   4. get_event_summary() is recalculated and now reports escrow.
--   5. admin_escrow_audit() lets you verify escrow behaved.
--
-- Money model: PayMongo settles to the FairTix merchant account, so "escrow"
-- here is the platform's ledger of what is owed to the organizer and when it
-- becomes payable. Nothing is transferred to organizers by this app.
-- =============================================================================

alter table public.transactions
  add column if not exists escrow_settled_at timestamptz;

-- ── 1. Hold paid primary purchases ───────────────────────────────────────
create or replace function public.set_initial_escrow()
returns trigger
language plpgsql
as $$
begin
  if new.transaction_type::text = 'purchase' and new.status::text = 'completed' then
    if new.amount > 0 then
      new.escrow_status := 'held';
      new.escrow_amount := new.amount;
    else
      new.escrow_status := 'released';
      new.escrow_amount := 0;
      new.escrow_settled_at := now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_initial_escrow on public.transactions;
create trigger trg_set_initial_escrow
  before insert on public.transactions
  for each row execute procedure public.set_initial_escrow();

-- ── 2. Settle bookkeeping when escrow leaves 'held' ──────────────────────
create or replace function public.settle_escrow()
returns trigger
language plpgsql
as $$
begin
  if new.escrow_status::text is distinct from old.escrow_status::text
     and new.escrow_status::text in ('released', 'refunded') then
    new.escrow_amount := 0;
    new.escrow_settled_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_settle_escrow on public.transactions;
create trigger trg_settle_escrow
  before update of escrow_status on public.transactions
  for each row execute procedure public.settle_escrow();

-- ── 3. Completion also releases unscanned (no-show) escrow ───────────────
create or replace function public.complete_finished_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_count integer;
begin
  with done as (
    update public.events
       set status = 'completed', updated_at = now()
     where status = 'published'
       and coalesce(event_end_date, event_start_date) < v_today
    returning event_id
  ),
  rel as (
    update public.transactions tr
       set escrow_status = 'released'
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
     where t.ticket_id = tr.ticket_id
       and tt.event_id in (select event_id from done)
       and tr.transaction_type::text = 'purchase'
       and tr.status::text = 'completed'
       and tr.escrow_status::text = 'held'
    returning tr.transaction_id
  )
  select count(*) into v_count from done;
  return v_count;
end;
$$;

revoke all on function public.complete_finished_events() from public, anon;
grant execute on function public.complete_finished_events() to authenticated;

-- Events completed BEFORE this file ran: release anything still held.
update public.transactions tr
   set escrow_status = 'released'
  from public.tickets t
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e on e.event_id = tt.event_id
 where t.ticket_id = tr.ticket_id
   and e.status::text = 'completed'
   and tr.transaction_type::text = 'purchase'
   and tr.status::text = 'completed'
   and tr.escrow_status::text = 'held';

-- ── 4. Corrected organizer summary ───────────────────────────────────────
-- Definitions (all for primary sales; a multi-day parent rolls up its days):
--   tickets_sold    completed purchases (refunded ones are NOT counted)
--   gross_revenue   sum of what buyers paid for those tickets
--   platform_fees   FairTix's cut (8/9/10%) on those tickets
--   net_revenue     gross - fees = what the organizer is owed
--   refunded_*      purchases refunded after a cancellation
--   checked_in      tickets scanned at the door
--   no_shows        sold tickets never scanned
--   resale_count    completed resales of this event's tickets
--   escrow_held     organizer share still held (entry not yet scanned)
--   escrow_released organizer share released (scanned, or event ended)
--   Invariant: escrow_held + escrow_released = net_revenue.
drop function if exists public.get_event_summary(uuid);

create or replace function public.get_event_summary(p_event_id uuid)
returns table(
  tickets_sold integer,
  gross_revenue numeric,
  platform_fees numeric,
  net_revenue numeric,
  refunded_tickets integer,
  refunded_amount numeric,
  tickets_checked_in integer,
  no_shows integer,
  resale_count integer,
  escrow_held numeric,
  escrow_released numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events%rowtype;
begin
  select * into v_event from public.events where event_id = p_event_id;
  if not found then
    raise exception 'This event could not be found.';
  end if;
  if auth.uid() is null or (
    not public.is_admin() and v_event.organizer_id <> auth.uid()
  ) then
    raise exception 'You are not allowed to view this event summary.';
  end if;

  return query
  with scope as (
    select e.event_id
    from public.events e
    where e.event_id = p_event_id or e.parent_event_id = p_event_id
  ),
  scope_tickets as (
    select t.ticket_id, t.ticket_status::text as tstatus
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    where tt.event_id in (select event_id from scope)
  ),
  purchases as (
    -- A purchase whose ticket was canceled (event canceled) counts as
    -- refunded even for a resold ticket, so it is never reported as a sale.
    select tr.ticket_id, tr.amount, tr.platform_fee,
           case when st.tstatus = 'canceled' then 'refunded'
                else tr.status::text end as pstatus,
           tr.escrow_status::text as pescrow
    from public.transactions tr
    join scope_tickets st on st.ticket_id = tr.ticket_id
    where tr.transaction_type::text = 'purchase'
      and tr.status::text in ('completed', 'refunded')
  ),
  resales as (
    select count(*) as n
    from public.transactions tr
    where tr.transaction_type::text = 'resale'
      and tr.status::text = 'completed'
      and tr.ticket_id in (select ticket_id from scope_tickets)
  )
  select
    (count(*) filter (where p.pstatus = 'completed'))::integer,
    coalesce(sum(p.amount) filter (where p.pstatus = 'completed'), 0),
    coalesce(sum(p.platform_fee) filter (where p.pstatus = 'completed'), 0),
    coalesce(sum(p.amount - p.platform_fee) filter (where p.pstatus = 'completed'), 0),
    (count(*) filter (where p.pstatus = 'refunded'))::integer,
    coalesce(sum(p.amount) filter (where p.pstatus = 'refunded'), 0),
    (select count(*) from scope_tickets where tstatus = 'used')::integer,
    (count(*) filter (
       where p.pstatus = 'completed' and s.tstatus is distinct from 'used'
     ))::integer,
    (select n from resales)::integer,
    coalesce(sum(p.amount - p.platform_fee)
      filter (where p.pstatus = 'completed' and p.pescrow = 'held'), 0),
    coalesce(sum(p.amount - p.platform_fee)
      filter (where p.pstatus = 'completed' and p.pescrow = 'released'), 0)
  from purchases p
  left join scope_tickets s on s.ticket_id = p.ticket_id;
end;
$$;

revoke all on function public.get_event_summary(uuid) from public, anon;
grant execute on function public.get_event_summary(uuid) to authenticated;

-- ── 5. Admin check: did escrow behave? ───────────────────────────────────
-- Every "should be 0" column that is not 0 points at a bug or a manual edit.
create or replace function public.admin_escrow_audit()
returns table(
  held_count integer,
  held_amount numeric,
  released_after_scan integer,
  released_at_completion integer,
  refunded_count integer,
  held_on_completed_events integer,   -- should be 0
  released_too_early integer          -- should be 0
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can run the escrow audit.';
  end if;

  return query
  with x as (
    select tr.escrow_status::text as es, tr.amount, tr.status::text as ps,
           t.ticket_status::text as ts, e.status::text as evs
    from public.transactions tr
    join public.tickets t on t.ticket_id = tr.ticket_id
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where tr.transaction_type::text = 'purchase'
  )
  select
    (count(*) filter (where es = 'held' and ps = 'completed'))::integer,
    coalesce(sum(amount) filter (where es = 'held' and ps = 'completed'), 0),
    (count(*) filter (where es = 'released' and ts = 'used'))::integer,
    (count(*) filter (where es = 'released' and ts <> 'used' and evs = 'completed' and amount > 0))::integer,
    (count(*) filter (where es = 'refunded'))::integer,
    (count(*) filter (where es = 'held' and evs = 'completed'))::integer,
    (count(*) filter (where es = 'released' and ts <> 'used' and evs in ('published', 'draft') and amount > 0))::integer
  from x;
end;
$$;

revoke all on function public.admin_escrow_audit() from public, anon;
grant execute on function public.admin_escrow_audit() to authenticated;
