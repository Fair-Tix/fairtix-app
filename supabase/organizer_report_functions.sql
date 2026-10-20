-- =============================================================================
-- FairTix — organizer report export (plan-gated)
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- purchase_functions.sql and revenue_functions.sql. Safe to re-run.
--
-- Plan rule: report export is a per-plan switch ("Includes report export" on
-- the plan in Admin > Platform Settings, subscription_plans.can_export), not a
-- fixed list of plan names. The plan is the one the organizer bought
-- (organizer_subscriptions.plan_id).
--
-- Both functions are enforced here, on the server, so hiding the button in
-- the app is a convenience and not the only protection.
-- =============================================================================

-- ── Can the signed-in organizer export reports? ─────────────────────────
-- True only for an organizer whose latest active subscription, one that has
-- not run out, is on a plan that includes export (the "Includes report export"
-- switch on the plan in Admin > Platform Settings; see subscription_plans.sql).
-- The app calls this to decide whether to show the export buttons as unlocked.
create or replace function public.organizer_can_export()
returns boolean
language sql stable
security definer set search_path = public
as $$
  select coalesce((
    select coalesce(p.can_export, s.monthly_fee >= 699)
    from public.organizer_subscriptions s
    join public.users u on u.id = s.user_id
    left join public.subscription_plans p on p.plan_id = s.plan_id
    where s.user_id = auth.uid()
      and u.role = 'organizer'
      and s.status = 'active'
      and current_date between s.start_date and s.end_date
    order by s.start_date desc, s.created_at desc
    limit 1
  ), false);
$$;

revoke all on function public.organizer_can_export() from public, anon;
grant execute on function public.organizer_can_export() to authenticated;

-- ── Organizer revenue report: one row per event ─────────────────────────
-- The caller's own events only (multi-day runs are rolled up under their
-- parent, like the Revenue Report screen). Refunded sales (fee status
-- 'withheld') are excluded. Optional date range on the purchase date
-- (p_from inclusive, p_to exclusive, null = no limit). Raises for anyone
-- whose plan does not allow exporting.
create or replace function public.organizer_revenue_report(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
returns table (
  event_title   text,
  event_status  text,
  event_date    date,
  tickets_sold  bigint,
  gross_revenue numeric,
  platform_fees numeric,
  net_payout    numeric
)
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not public.organizer_can_export() then
    raise exception 'Your plan does not include report export. Upgrade to a plan that does.';
  end if;

  return query
  select
    r.title,
    r.status::text,
    r.event_start_date,
    count(f.fee_id),
    coalesce(sum(f.gross_amount), 0),
    coalesce(sum(f.fee_amount), 0),
    coalesce(sum(f.net_amount), 0)
  from public.events e
  join public.events r         on r.event_id = coalesce(e.parent_event_id, e.event_id)
  left join public.ticket_tiers tt on tt.event_id = e.event_id
  left join public.tickets t       on t.tier_id = tt.tier_id
  left join public.transactions tr on tr.ticket_id = t.ticket_id
                                  and tr.transaction_type = 'purchase'
                                  and (p_from is null or tr.created_at >= p_from)
                                  and (p_to   is null or tr.created_at <  p_to)
  left join public.organizer_fees f on f.transaction_id = tr.transaction_id
                                   and f.status <> 'withheld'
  where r.organizer_id = auth.uid()
    and r.parent_event_id is null
  group by r.event_id, r.title, r.status, r.event_start_date
  order by r.event_start_date desc, r.title;
end;
$$;

revoke all on function public.organizer_revenue_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.organizer_revenue_report(timestamptz, timestamptz) to authenticated;
