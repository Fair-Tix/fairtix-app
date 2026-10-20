-- =============================================================================
-- FairTix - organizer subscription payments (PayMongo)
-- Run in the Supabase SQL Editor AFTER schema.sql / policies.sql AND
-- subscription_plans.sql (the plans an organizer can buy now live in that
-- table). Safe to re-run.
--
-- Before this, the app wrote the organizer's plan straight into
-- public.organizer_subscriptions, so no payment was needed. Now a plan is
-- only activated by the paymongo-verify / paymongo-webhook Edge Functions
-- (service_role) AFTER PayMongo confirms the Checkout Session is paid.
--
-- 1. organizer_subscription_payments: a ledger with one row per PayMongo
--    session that has been applied. verify and webhook both call
--    fulfill_organizer_subscription for the same payment, and a buyer can
--    re-verify an old session at any time; the ledger's primary key makes
--    every call after the first a harmless no-op, so one payment can never
--    extend a plan twice (even after a later payment has replaced the row's
--    payment_ref).
-- 2. The client-side write policies are dropped, otherwise an organizer could
--    still activate a plan for free by calling the REST API directly.
-- 3. fulfill_organizer_subscription is locked to service_role. It records the
--    plan the organizer bought (plan_id) and the fee that was actually paid.
--    RENEWAL: paying again for the plan the organizer already holds (and has
--    not yet run out) adds 30 days on top of the current end date, so renewing
--    early loses nothing. Buying a different plan, or buying after the old
--    plan ran out, starts a fresh 30 days from today.
-- =============================================================================

alter table public.organizer_subscriptions
  add column if not exists payment_ref text;

create unique index if not exists organizer_subscriptions_payment_ref_key
  on public.organizer_subscriptions (payment_ref)
  where payment_ref is not null;

-- Every payment that has been applied to a subscription.
create table if not exists public.organizer_subscription_payments (
  payment_ref text primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  plan_id     uuid references public.subscription_plans(plan_id),
  amount      numeric(10,2) not null,
  applied_at  timestamptz not null default now()
);

-- Server-side only: no policies, no client access.
alter table public.organizer_subscription_payments enable row level security;
revoke all on public.organizer_subscription_payments from anon, authenticated;

-- Payments applied before this ledger existed (only the latest per organizer
-- is still recorded on its subscription row).
insert into public.organizer_subscription_payments
  (payment_ref, user_id, plan_id, amount)
select s.payment_ref, s.user_id, s.plan_id, s.monthly_fee
  from public.organizer_subscriptions s
 where s.payment_ref is not null
on conflict (payment_ref) do nothing;

-- Organizers must no longer insert/update their own subscription rows.
-- (If you created differently named policies for this, drop those too: only
-- "org_subs_select" and "org_subs_write_admin_only" should remain.)
drop policy if exists "org_subs_insert_own" on public.organizer_subscriptions;
drop policy if exists "org_subs_update_own_or_admin" on public.organizer_subscriptions;

-- Older version took (user, plan NAME, ref) with prices hardcoded here.
drop function if exists public.fulfill_organizer_subscription(uuid, text, text);

create or replace function public.fulfill_organizer_subscription(
  p_user_id     uuid,
  p_plan_id     uuid,
  p_fee         numeric,
  p_payment_ref text
)
returns table (plan_name text, renews_at date, can_export boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan          public.subscription_plans%rowtype;
  v_existing      uuid;
  v_existing_plan uuid;
  v_existing_end  date;
  v_start         date := current_date;
  v_end           date := current_date + 30;
  v_extend        boolean := false;
  v_rows          integer;
begin
  select * into v_plan
    from public.subscription_plans sp
   where sp.plan_id = p_plan_id;
  if not found then
    raise exception 'Unknown subscription plan.';
  end if;

  -- p_fee is the price the organizer was actually charged (written by
  -- paymongo-checkout from the plan at checkout time), so a price change by
  -- the admin between checkout and payment never mis-records the payment.
  if p_fee is null or p_fee < 20 then
    raise exception 'Invalid subscription fee.';
  end if;

  if not exists (
    select 1 from public.users u where u.id = p_user_id and u.role = 'organizer'
  ) then
    raise exception 'Only organizer accounts can hold a subscription.';
  end if;

  -- Serialise payments for one organizer so two payments landing together
  -- (or verify + webhook) can't both read the same end date.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  -- Already applied? (verify and webhook both run for the same payment, and
  -- an old session can be re-verified later.) Nothing changes; report the
  -- organizer's current end date.
  insert into public.organizer_subscription_payments
    (payment_ref, user_id, plan_id, amount)
  values (p_payment_ref, p_user_id, p_plan_id, p_fee)
  on conflict (payment_ref) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    select s.end_date into v_end
      from public.organizer_subscriptions s
     where s.user_id = p_user_id and s.status = 'active'
     order by s.start_date desc
     limit 1;
    return query select v_plan.name, coalesce(v_end, current_date), v_plan.can_export;
    return;
  end if;

  -- One active row per organizer (login reads the most recent active row).
  select s.subscription_id, s.plan_id, s.end_date
    into v_existing, v_existing_plan, v_existing_end
    from public.organizer_subscriptions s
   where s.user_id = p_user_id and s.status = 'active'
   order by s.start_date desc
   limit 1;

  if v_existing is not null then
    -- Renewing the same plan before it runs out: stack the 30 days on the
    -- remaining time.
    if v_existing_plan = p_plan_id and v_existing_end >= v_start then
      v_extend := true;
      v_end := v_existing_end + 30;
    end if;

    update public.organizer_subscriptions
       set start_date  = case when v_extend then start_date else v_start end,
           end_date    = v_end,
           monthly_fee = p_fee,
           plan_id     = p_plan_id,
           status      = 'active',
           payment_ref = p_payment_ref
     where subscription_id = v_existing;
  else
    insert into public.organizer_subscriptions
      (user_id, start_date, end_date, status, monthly_fee, plan_id, payment_ref)
    values
      (p_user_id, v_start, v_end, 'active', p_fee, p_plan_id, p_payment_ref);
  end if;

  return query select v_plan.name, v_end, v_plan.can_export;
end;
$$;

revoke all on function public.fulfill_organizer_subscription(uuid, uuid, numeric, text)
  from public, anon, authenticated;
grant execute on function public.fulfill_organizer_subscription(uuid, uuid, numeric, text)
  to service_role;
