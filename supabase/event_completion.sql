-- =============================================================================
-- FairTix — automatic event completion + organizer event summary.
-- Apply after organizer_event_functions.sql. Safe to re-run.
--
-- An event is "finished" once the day AFTER its last day has started
-- (Philippine time). e.g. scheduled Oct 30 -> becomes 'completed' on Oct 31.
-- Completed events drop out of the eventgoer catalogue (which only reads
-- status = 'published') and show as Completed on the organizer side.
-- =============================================================================

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
  -- Parents, single-day events and each generated day of a multi-day event.
  -- (Day rows have no end date, so their own start date is their last day.)
  update public.events
  set status = 'completed', updated_at = now()
  where status = 'published'
    and coalesce(event_end_date, event_start_date) < v_today;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.complete_finished_events() from public, anon;
grant execute on function public.complete_finished_events() to authenticated;

-- Summary shown to the organizer (or an admin) for a finished event.
-- For a multi-day parent, figures are rolled up across all of its days.
create or replace function public.get_event_summary(p_event_id uuid)
returns table(
  tickets_sold integer,
  gross_revenue numeric,
  platform_fees numeric,
  net_revenue numeric,
  tickets_checked_in integer,
  no_shows integer,
  resale_count integer
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
    select t.ticket_id, t.ticket_status
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    where tt.event_id in (select event_id from scope)
  ),
  primary_sales as (
    select tr.ticket_id, tr.amount, tr.platform_fee
    from public.transactions tr
    where tr.transaction_type = 'purchase'
      and tr.status = 'completed'
      and tr.ticket_id in (select ticket_id from scope_tickets)
  ),
  resales as (
    select count(*)::integer as n
    from public.transactions tr
    where tr.transaction_type = 'resale'
      and tr.status = 'completed'
      and tr.ticket_id in (select ticket_id from scope_tickets)
  )
  select
    (select count(*) from primary_sales)::integer,
    coalesce((select sum(amount) from primary_sales), 0),
    coalesce((select sum(platform_fee) from primary_sales), 0),
    coalesce((select sum(amount - platform_fee) from primary_sales), 0),
    (select count(*) from scope_tickets where ticket_status = 'used')::integer,
    greatest(
      (select count(*) from primary_sales)
      - (select count(*) from scope_tickets where ticket_status = 'used'),
      0
    )::integer,
    (select n from resales);
end;
$$;

revoke all on function public.get_event_summary(uuid) from public, anon;
grant execute on function public.get_event_summary(uuid) to authenticated;

-- Run once now so already-past events are fixed immediately.
select public.complete_finished_events();

-- Run daily at 00:05 Philippine time (16:05 UTC). Requires the pg_cron
-- extension (Supabase Dashboard -> Database -> Extensions -> pg_cron). If it
-- is unavailable this block is skipped; the app also calls
-- complete_finished_events() whenever event lists load, so it still works.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('fairtix-complete-events')
  where exists (select 1 from cron.job where jobname = 'fairtix-complete-events');
  perform cron.schedule(
    'fairtix-complete-events',
    '5 16 * * *',
    'select public.complete_finished_events();'
  );
exception when others then
  raise notice 'pg_cron not scheduled: %', sqlerrm;
end;
$$;
