-- =============================================================================
-- FairTix — per-plan platform fees + admin revenue summary
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run.
--
-- Fee rate by organizer plan (organizer-subscription-plan.dart):
--   Basic    (monthly_fee 299)  -> 8%
--   Standard (monthly_fee 699)  -> 9%
--   Premium  (monthly_fee 1499) -> 10%
-- organizer_subscriptions has no plan-name column (only monthly_fee), so the
-- plan is derived from the fee, the same mapping the Flutter app uses.
--
-- What this does NOT change: the amount the buyer pays. Checkout, the
-- PayMongo link and transactions.platform_fee still use the flat 10% from
-- kPrimaryPlatformFeeRate / _do_ticket_purchase. This file records the
-- organizer's plan-based commission in organizer_fees (the table built for
-- it), one row per completed primary purchase.
-- =============================================================================

-- ── Plan fee rate ───────────────────────────────────────────────────────
create or replace function public.plan_fee_rate(p_monthly_fee numeric)
returns numeric
language sql immutable
as $$
  select case p_monthly_fee
    when 299  then 0.08
    when 699  then 0.09
    when 1499 then 0.10
    else 0.10  -- unknown fee: fall back to the highest (standard) rate
  end;
$$;

-- One fee row per transaction, so the trigger and the backfill below can
-- never double-count.
create unique index if not exists organizer_fees_transaction_uidx
  on public.organizer_fees (transaction_id);

-- ── Record the organizer fee when a primary purchase completes ──────────
create or replace function public.record_organizer_fee()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_organizer_id uuid;
  v_gross        numeric(10,2);
  v_monthly_fee  numeric;
  v_rate         numeric(5,4);
  v_fee          numeric(10,2);
begin
  if new.transaction_type <> 'purchase' or new.status <> 'completed' then
    return new;
  end if;

  select e.organizer_id, t.purchase_price
    into v_organizer_id, v_gross
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  if v_organizer_id is null then
    return new;
  end if;

  select s.monthly_fee into v_monthly_fee
    from public.organizer_subscriptions s
    where s.user_id = v_organizer_id and s.status = 'active'
    order by s.start_date desc, s.created_at desc
    limit 1;

  v_rate := public.plan_fee_rate(v_monthly_fee);
  v_fee  := round(v_gross * v_rate, 2);

  insert into public.organizer_fees
    (transaction_id, organizer_id, gross_amount, fee_rate, fee_amount, net_amount, status)
  values
    (new.transaction_id, v_organizer_id, v_gross, v_rate, v_fee, v_gross - v_fee, 'pending')
  on conflict (transaction_id) do nothing;

  return new;
end;
$$;

revoke all on function public.record_organizer_fee() from public, anon, authenticated;

drop trigger if exists on_purchase_record_organizer_fee on public.transactions;
create trigger on_purchase_record_organizer_fee
  after insert on public.transactions
  for each row execute procedure public.record_organizer_fee();

-- ── Backfill purchases that happened before this trigger existed ────────
-- Uses each organizer's CURRENT plan, since the plan at purchase time was
-- not recorded. Skip this block if you only have test data you plan to wipe.
insert into public.organizer_fees
  (transaction_id, organizer_id, gross_amount, fee_rate, fee_amount, net_amount, status)
select
  tr.transaction_id,
  e.organizer_id,
  t.purchase_price,
  public.plan_fee_rate(sub.monthly_fee),
  round(t.purchase_price * public.plan_fee_rate(sub.monthly_fee), 2),
  t.purchase_price - round(t.purchase_price * public.plan_fee_rate(sub.monthly_fee), 2),
  'pending'
from public.transactions tr
join public.tickets t        on t.ticket_id = tr.ticket_id
join public.ticket_tiers tt  on tt.tier_id = t.tier_id
join public.events e         on e.event_id = tt.event_id
left join lateral (
  select s.monthly_fee
  from public.organizer_subscriptions s
  where s.user_id = e.organizer_id and s.status = 'active'
  order by s.start_date desc, s.created_at desc
  limit 1
) sub on true
where tr.transaction_type = 'purchase'
  and tr.status = 'completed'
on conflict (transaction_id) do nothing;

-- ── Admin summary: totals per plan ──────────────────────────────────────
-- Returns only plans that have at least one fee row; the app fills in zero
-- rows for the rest. Admin-only (the table's RLS already limits reads, and
-- this raises for anyone else too, since it runs as SECURITY DEFINER).
create or replace function public.admin_revenue_by_plan()
returns table (
  plan    text,
  rate    numeric,
  tickets bigint,
  gross   numeric,
  fees    numeric,
  net     numeric
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
    case f.fee_rate when 0.0800 then 'Basic' when 0.0900 then 'Standard' else 'Premium' end,
    f.fee_rate::numeric,
    count(*),
    sum(f.gross_amount),
    sum(f.fee_amount),
    sum(f.net_amount)
  from public.organizer_fees f
  group by f.fee_rate
  order by f.fee_rate;
end;
$$;

revoke all on function public.admin_revenue_by_plan() from public, anon;
grant execute on function public.admin_revenue_by_plan() to authenticated;
