-- =============================================================================
-- FairTix — per-plan platform fees + admin revenue summary
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql (which defines plan_fee_rate and the fee model).
-- Safe to re-run.
--
-- Fee model (see purchase_functions.sql): the buyer pays the listed ticket
-- price; FairTix's fee (the rate on the organizer's plan, from
-- subscription_plans) is taken out of the organizer's proceeds. Each completed
-- primary purchase therefore has transactions.amount = ticket price and
-- transactions.platform_fee = FairTix's cut, and this file records the same
-- numbers per organizer in organizer_fees (the table built for it), one row
-- per purchase, so the Transaction Report and Revenue Report always agree.
-- =============================================================================

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
  v_rate         numeric(5,4);
begin
  if new.transaction_type <> 'purchase' or new.status <> 'completed' then
    return new;
  end if;

  select e.organizer_id
    into v_organizer_id
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  if v_organizer_id is null then
    return new;
  end if;

  -- Amounts come straight from the transaction (what the buyer paid and the
  -- fee _do_ticket_purchase charged for it) so they can never drift apart;
  -- the rate is stored for display (the Basic/Standard/Premium split).
  v_rate := public.organizer_fee_rate(v_organizer_id);

  insert into public.organizer_fees
    (transaction_id, organizer_id, gross_amount, fee_rate, fee_amount, net_amount, status)
  values
    (new.transaction_id, v_organizer_id, new.amount, v_rate, new.platform_fee, new.amount - new.platform_fee, 'pending')
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
-- (If you also run fee_model_migration.sql, run it BEFORE this block so old
-- transactions are already restated to the current fee model.)
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
-- Returns one row per fee rate that has at least one fee row; the app adds
-- zero rows for active plans with no sales. The plan name is looked up in
-- public.subscription_plans by fee rate (plans sharing a rate are joined with
-- ' / '). organizer_fees records the rate charged, not the plan, so a rate no
-- plan uses any more (the admin changed it later) is labelled with the rate.
-- Admin-only (the table's RLS already limits reads, and
-- this raises for anyone else too, since it runs as SECURITY DEFINER).
-- Optional date range (p_from inclusive, p_to exclusive) filters on the date of
-- the underlying purchase; null means no limit on that side.
drop function if exists public.admin_revenue_by_plan();

create or replace function public.admin_revenue_by_plan(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
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
    coalesce(
      (select string_agg(p.name, ' / ' order by p.sort_order, p.name)
         from public.subscription_plans p
        where p.platform_fee_rate = f.fee_rate),
      trim(trailing '.' from trim(trailing '0' from round(f.fee_rate * 100, 2)::text))
        || '% (former rate)'
    ),
    f.fee_rate::numeric,
    count(*),
    sum(f.gross_amount),
    sum(f.fee_amount),
    sum(f.net_amount)
  from public.organizer_fees f
  join public.transactions tr on tr.transaction_id = f.transaction_id
  where f.status <> 'withheld'  -- refunded sales earn no fee (see refund_functions.sql)
    and (p_from is null or tr.created_at >= p_from)
    and (p_to   is null or tr.created_at <  p_to)
  group by f.fee_rate
  order by f.fee_rate;
end;
$$;

revoke all on function public.admin_revenue_by_plan(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_revenue_by_plan(timestamptz, timestamptz) to authenticated;
