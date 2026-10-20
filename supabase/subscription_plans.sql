-- =============================================================================
-- FairTix - admin-editable organizer subscription plans
-- Run in the Supabase SQL Editor AFTER schema.sql and policies.sql, and BEFORE
-- re-running purchase_functions.sql, organizer_report_functions.sql,
-- organizer_event_functions.sql and organizer_subscription_payment.sql (those
-- files now read their plan rules from the table created here). Safe to re-run.
--
-- Until now the plans (Basic / Standard / Premium) were hardcoded in the app,
-- in three Edge Functions and in several SQL functions. This file makes
-- public.subscription_plans the single source of truth:
--
--   * Admin > Platform Settings > Subscription Plans edits it through
--     admin_save_subscription_plans (admin-only).
--   * Organizers see only the ACTIVE plans on the plan screen.
--   * The same row drives what the plan actually enforces: the monthly price
--     charged through PayMongo, the platform fee rate on primary sales, the
--     events/month, tickets/day and multi-day limits, and report export.
--   * "Benefits" is the list of lines shown on each plan card. It is display
--     text; the numeric columns are what is enforced.
--
-- Removing a plan in the admin screen never deletes it (existing subscribers
-- keep it): it is switched to inactive, so organizers can no longer buy it.
-- =============================================================================

create table if not exists public.subscription_plans (
  plan_id              uuid primary key default gen_random_uuid(),
  name                 text not null check (btrim(name) <> ''),
  -- PayMongo cannot charge less than PHP 20.
  monthly_fee          numeric(10,2) not null check (monthly_fee >= 20),
  -- Fraction of each primary ticket sale kept by FairTix (0.08 = 8%).
  platform_fee_rate    numeric(5,4) not null
                       check (platform_fee_rate >= 0 and platform_fee_rate <= 1),
  -- NULL on any limit means unlimited.
  max_events_per_month integer check (max_events_per_month is null or max_events_per_month > 0),
  max_tickets_per_day  integer check (max_tickets_per_day is null or max_tickets_per_day > 0),
  max_multiday_days    integer check (max_multiday_days is null or max_multiday_days > 0),
  can_export           boolean not null default false,
  benefits             text[] not null default '{}',
  badge                text,
  sort_order           integer not null default 0,
  is_active            boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create unique index if not exists subscription_plans_name_key
  on public.subscription_plans (lower(name));

-- Everyone signed in may READ plans; nobody writes directly (only the
-- admin_save_subscription_plans function below, which checks is_admin()).
alter table public.subscription_plans enable row level security;

drop policy if exists "subscription_plans_select_signed_in" on public.subscription_plans;
create policy "subscription_plans_select_signed_in"
  on public.subscription_plans for select
  using (auth.uid() is not null);

revoke all on public.subscription_plans from anon;
revoke insert, update, delete on public.subscription_plans from authenticated;

-- Seed the three existing plans the first time only.
insert into public.subscription_plans (
  name, monthly_fee, platform_fee_rate, max_events_per_month,
  max_tickets_per_day, max_multiday_days, can_export, benefits, badge, sort_order
)
select * from (values
  ('Basic', 299::numeric, 0.08::numeric, 3, 500, 3, false,
   array['Up to 3 events/month', 'Max 500 tickets/event day',
         'Multi-day events up to 3 days', '8% platform fee/ticket',
         'Unlimited scanner sessions']::text[],
   null::text, 1),
  ('Standard', 699, 0.09, 9, 5000, 14, true,
   array['Up to 9 events/month', 'Max 5,000 tickets/event day',
         'Multi-day events up to 14 days', '9% platform fee/ticket',
         'Unlimited scanner sessions', 'CSV export & analytics']::text[],
   null, 2),
  ('Premium', 1499, 0.10, null, null, null, true,
   array['Unlimited events', 'Unlimited ticket capacity',
         'Unlimited multi-day length', '10% platform fee/ticket',
         'Unlimited scanner sessions',
         'CSV export & enhanced analytics']::text[],
   'BEST VALUE', 3)
) as seed(name, monthly_fee, platform_fee_rate, max_events_per_month,
          max_tickets_per_day, max_multiday_days, can_export, benefits, badge,
          sort_order)
where not exists (select 1 from public.subscription_plans);

-- Which plan an organizer bought. Older rows only have monthly_fee, so they
-- are matched to a plan by that fee once, here.
alter table public.organizer_subscriptions
  add column if not exists plan_id uuid references public.subscription_plans(plan_id);

update public.organizer_subscriptions s
   set plan_id = (
     select p.plan_id
       from public.subscription_plans p
      where p.monthly_fee = s.monthly_fee
      order by p.is_active desc, p.sort_order
      limit 1
   )
 where s.plan_id is null;

-- The plan an organizer is on right now (latest active, in-date subscription).
-- Falls back to matching by fee for any row that still has no plan_id.
-- Returns a row of NULLs (plan_id is null) when there is no active plan.
create or replace function public._organizer_plan(p_user_id uuid)
returns public.subscription_plans
language sql stable
security definer set search_path = public
as $$
  select p.*
  from public.organizer_subscriptions s
  join public.subscription_plans p
    on p.plan_id = coalesce(
         s.plan_id,
         (select p2.plan_id
            from public.subscription_plans p2
           where p2.monthly_fee = s.monthly_fee
           order by p2.is_active desc, p2.sort_order
           limit 1)
       )
  where s.user_id = p_user_id
    and s.status = 'active'
    and current_date between s.start_date and s.end_date
  order by s.start_date desc, s.created_at desc
  limit 1;
$$;

revoke all on function public._organizer_plan(uuid) from public, anon, authenticated;

-- ── Admin: save the whole plan list ──────────────────────────────────────
-- p_plans is a JSON array. Each item:
--   { plan_id?, name, monthly_fee, platform_fee_rate, max_events_per_month,
--     max_tickets_per_day, max_multiday_days, can_export, benefits[], badge,
--     is_active }
-- Items with a known plan_id update that plan; items without one create a new
-- plan; the order of the array becomes the display order. Existing plans left
-- out of the array are switched to inactive (never deleted).
create or replace function public.admin_save_subscription_plans(p_plans jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_item     jsonb;
  v_id       uuid;
  v_name     text;
  v_fee      numeric;
  v_rate     numeric;
  v_events   integer;
  v_tickets  integer;
  v_days     integer;
  v_benefits text[];
  v_badge    text;
  v_active   boolean;
  v_export   boolean;
  v_kept     uuid[] := '{}';
  v_order    integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Only admins can change subscription plans.';
  end if;
  if jsonb_typeof(p_plans) is distinct from 'array'
     or jsonb_array_length(p_plans) = 0 then
    raise exception 'Add at least one plan.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_plans) as e(item)
    group by lower(btrim(coalesce(e.item->>'name', '')))
    having count(*) > 1
  ) then
    raise exception 'Each plan needs a different name.';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(p_plans) as e(item)
    where coalesce((e.item->>'is_active')::boolean, true)
  ) then
    raise exception 'At least one plan must stay active so organizers can subscribe.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('subscription_plans', 0));

  for v_item in select e.item from jsonb_array_elements(p_plans) as e(item)
  loop
    v_order := v_order + 1;
    v_name := btrim(coalesce(v_item->>'name', ''));
    if v_name = '' then
      raise exception 'Every plan needs a name.';
    end if;

    v_fee := (v_item->>'monthly_fee')::numeric;
    if v_fee is null or v_fee < 20 then
      raise exception 'The monthly price of "%" must be at least PHP 20 (PayMongo minimum).', v_name;
    end if;

    v_rate := (v_item->>'platform_fee_rate')::numeric;
    if v_rate is null or v_rate < 0 or v_rate > 1 then
      raise exception 'The platform fee of "%" must be between 0%% and 100%%.', v_name;
    end if;

    v_events  := nullif(v_item->>'max_events_per_month', '')::integer;
    v_tickets := nullif(v_item->>'max_tickets_per_day', '')::integer;
    v_days    := nullif(v_item->>'max_multiday_days', '')::integer;
    if (v_events is not null and v_events <= 0)
       or (v_tickets is not null and v_tickets <= 0)
       or (v_days is not null and v_days <= 0) then
      raise exception 'Limits of "%" must be positive numbers (leave blank for unlimited).', v_name;
    end if;

    v_export := coalesce((v_item->>'can_export')::boolean, false);
    v_active := coalesce((v_item->>'is_active')::boolean, true);
    v_badge  := nullif(btrim(coalesce(v_item->>'badge', '')), '');
    v_benefits := coalesce(
      array(
        select btrim(b.line)
        from jsonb_array_elements_text(
               coalesce(v_item->'benefits', '[]'::jsonb)
             ) as b(line)
        where btrim(b.line) <> ''
      ),
      '{}'
    );

    v_id := nullif(v_item->>'plan_id', '')::uuid;
    if v_id is not null and exists (
      select 1 from public.subscription_plans where plan_id = v_id
    ) then
      update public.subscription_plans
         set name = v_name,
             monthly_fee = v_fee,
             platform_fee_rate = v_rate,
             max_events_per_month = v_events,
             max_tickets_per_day = v_tickets,
             max_multiday_days = v_days,
             can_export = v_export,
             benefits = v_benefits,
             badge = v_badge,
             sort_order = v_order,
             is_active = v_active,
             updated_at = now()
       where plan_id = v_id;
    else
      insert into public.subscription_plans (
        name, monthly_fee, platform_fee_rate, max_events_per_month,
        max_tickets_per_day, max_multiday_days, can_export, benefits, badge,
        sort_order, is_active
      )
      values (
        v_name, v_fee, v_rate, v_events, v_tickets, v_days, v_export,
        v_benefits, v_badge, v_order, v_active
      )
      returning plan_id into v_id;
    end if;
    v_kept := v_kept || v_id;
  end loop;

  update public.subscription_plans
     set is_active = false, updated_at = now()
   where is_active and not (plan_id = any(v_kept));
exception
  when unique_violation then
    raise exception 'Each plan needs a different name.';
end;
$$;

revoke all on function public.admin_save_subscription_plans(jsonb)
  from public, anon;
grant execute on function public.admin_save_subscription_plans(jsonb)
  to authenticated;
