-- =============================================================================
-- FairTix — admin reports (transaction + revenue), for CSV export
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- purchase_functions.sql, revenue_functions.sql and refund_functions.sql.
-- Safe to re-run.
--
-- Both functions take an optional date range (p_from inclusive, p_to
-- exclusive, null = no limit) and are admin-only: they run as SECURITY
-- DEFINER but return zero rows unless the caller is an admin.
-- =============================================================================

-- ── Transaction report: every transaction in the range ──────────────────
create or replace function public.admin_transaction_report(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
returns table (
  tx_id        uuid,
  tx_date      timestamptz,
  tx_type      text,
  tx_status    text,
  event_title  text,
  tier_name    text,
  buyer_name   text,
  buyer_email  text,
  seller_name  text,
  amount       numeric,
  platform_fee numeric,
  escrow       text
)
language sql stable
security definer set search_path = public
as $$
  select
    tr.transaction_id,
    tr.created_at,
    tr.transaction_type::text,
    tr.status::text,
    e.title,
    tt.tier_name,
    b.full_name,
    b.email,
    s.full_name,
    tr.amount,
    tr.platform_fee,
    tr.escrow_status::text
  from public.transactions tr
  left join public.tickets t       on t.ticket_id = tr.ticket_id
  left join public.ticket_tiers tt on tt.tier_id = t.tier_id
  left join public.events e        on e.event_id = tt.event_id
  left join public.users b         on b.id = tr.buyer_id
  left join public.users s         on s.id = tr.seller_id
  where public.is_admin()
    and (p_from is null or tr.created_at >= p_from)
    and (p_to   is null or tr.created_at <  p_to)
  order by tr.created_at desc;
$$;

revoke all on function public.admin_transaction_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_transaction_report(timestamptz, timestamptz) to authenticated;

-- ── Revenue report: one row per event + organizer + fee rate ────────────
-- Built from organizer_fees (written by the purchase trigger in
-- revenue_functions.sql). Refunded sales (fee status 'withheld') are
-- excluded, so the totals match the Revenue & Reports screen.
create or replace function public.admin_revenue_report(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
returns table (
  event_title    text,
  organizer_name text,
  plan_name      text,
  fee_rate       numeric,
  tickets_sold   bigint,
  gross_revenue  numeric,
  platform_fees  numeric,
  net_payout     numeric
)
language sql stable
security definer set search_path = public
as $$
  select
    e.title,
    coalesce(nullif(o.organization_name, ''), o.full_name),
    case f.fee_rate when 0.0800 then 'Basic' when 0.0900 then 'Standard' else 'Premium' end,
    f.fee_rate::numeric,
    count(*),
    sum(f.gross_amount),
    sum(f.fee_amount),
    sum(f.net_amount)
  from public.organizer_fees f
  join public.transactions tr on tr.transaction_id = f.transaction_id
  join public.tickets t       on t.ticket_id = tr.ticket_id
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e        on e.event_id = tt.event_id
  join public.users o         on o.id = f.organizer_id
  where public.is_admin()
    and f.status <> 'withheld'
    and (p_from is null or tr.created_at >= p_from)
    and (p_to   is null or tr.created_at <  p_to)
  group by e.event_id, e.title, o.id, o.organization_name, o.full_name, f.fee_rate
  order by sum(f.gross_amount) desc;
$$;

revoke all on function public.admin_revenue_report(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_revenue_report(timestamptz, timestamptz) to authenticated;
