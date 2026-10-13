-- =============================================================================
-- FairTix — admin dashboard + revenue chart data
-- Run in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- purchase_functions.sql and revenue_functions.sql (it reads organizer_fees,
-- which revenue_functions.sql fills). Safe to re-run.
--
-- All three functions are admin-only: they run as SECURITY DEFINER but raise
-- an error for anyone who is not an admin.
--
-- Money figures come from organizer_fees, so they match the Revenue &
-- Reports screen and the CSV exports exactly. Refunded sales (fee status
-- 'withheld', see refund_functions.sql) are excluded. Dates are grouped by
-- Philippine time (Asia/Manila), not UTC, so a sale at 9 PM does not land on
-- the next day.
-- =============================================================================

-- ── Dashboard headline numbers ──────────────────────────────────────────
create or replace function public.admin_dashboard_stats()
returns table (
  total_users      bigint,
  total_organizers bigint,
  total_events     bigint,
  tickets_sold     bigint,
  platform_revenue numeric
)
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can view platform statistics.';
  end if;

  return query
  select
    -- Eventgoers only (organizers and admins are counted separately / not at all).
    (select count(*) from public.users where role = 'buyer'),
    (select count(*) from public.users where role = 'organizer'),
    -- Top-level events: a multi-day run counts once, not once per day.
    (select count(*) from public.events where parent_event_id is null),
    -- One ticket row per purchase; canceled (refunded) tickets don't count.
    (select count(*) from public.tickets where ticket_status <> 'canceled'),
    (select coalesce(sum(fee_amount), 0) from public.organizer_fees where status <> 'withheld');
end;
$$;

revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

-- ── Revenue per day (the "Daily Revenue" chart) ─────────────────────────
-- Only days with at least one sale are returned; the app fills in zeros.
-- p_from inclusive, p_to exclusive, null = no limit.
create or replace function public.admin_revenue_daily(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
returns table (
  sale_date date,
  tickets   bigint,
  gross     numeric,
  fees      numeric
)
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can view platform revenue.';
  end if;

  return query
  select
    (tr.created_at at time zone 'Asia/Manila')::date,
    count(*),
    sum(f.gross_amount),
    sum(f.fee_amount)
  from public.organizer_fees f
  join public.transactions tr on tr.transaction_id = f.transaction_id
  where f.status <> 'withheld'
    and (p_from is null or tr.created_at >= p_from)
    and (p_to   is null or tr.created_at <  p_to)
  group by 1
  order by 1;
end;
$$;

revoke all on function public.admin_revenue_daily(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_revenue_daily(timestamptz, timestamptz) to authenticated;

-- ── Revenue per month of one year (the "Monthly Breakdown" table) ───────
create or replace function public.admin_revenue_monthly(p_year int)
returns table (
  month_no int,
  tickets  bigint,
  gross    numeric,
  fees     numeric,
  net      numeric
)
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can view platform revenue.';
  end if;

  return query
  select
    extract(month from tr.created_at at time zone 'Asia/Manila')::int,
    count(*),
    sum(f.gross_amount),
    sum(f.fee_amount),
    sum(f.net_amount)
  from public.organizer_fees f
  join public.transactions tr on tr.transaction_id = f.transaction_id
  where f.status <> 'withheld'
    and extract(year from tr.created_at at time zone 'Asia/Manila')::int = p_year
  group by 1
  order by 1;
end;
$$;

revoke all on function public.admin_revenue_monthly(int) from public, anon;
grant execute on function public.admin_revenue_monthly(int) to authenticated;
