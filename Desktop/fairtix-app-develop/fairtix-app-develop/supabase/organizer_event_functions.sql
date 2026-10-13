-- =============================================================================
-- FairTix — Organizer event management + admin oversight RPCs
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run (create or replace / if not exists).
--
-- Why RPCs: policies.sql deliberately blocks organizers from writing
-- `notifications` and from updating `transactions` / `tickets` (admin or
-- service_role only). Cancel Event therefore could never refund or notify
-- anyone from the client. These SECURITY DEFINER functions do the
-- all-or-nothing work server-side after checking the caller's identity.
--
-- Covers test-list items (Oct 9, 2026):
--   Event Management  — multi-day sub-events, plan limits, daily ticket cap,
--                       cancel whole event / single day, auto refunds,
--                       holder notifications
--   Admin             — organizer approve/reject + notify organizer,
--                       platform-wide announcements
-- =============================================================================

-- ── Missing column the app already writes to ─────────────────────────────
alter table public.events
  add column if not exists supporting_document_urls text[] not null default '{}',
  add column if not exists canceled_at timestamptz,
  add column if not exists cancel_reason text;

-- Allow the new refund status on tickets' escrow-linked flows without
-- touching existing enums: transactions.status already has 'refunded' and
-- escrow_status already has 'refunded'.

-- ── Plan limits (single source of truth) ─────────────────────────────────
-- Plan is derived from organizer_subscriptions.monthly_fee, exactly like the
-- app does (299 = Basic, 699 = Standard, 1499 = Premium).
-- NULL limit = unlimited.
--   Basic    : 3 events/month, 500 tickets per event day
--   Standard : 9 events/month, 5,000 tickets per event day
--   Premium  : unlimited
-- max_days_multi is NOT in the plan card copy — values below are a proposal;
-- change them here (and in organizer-subscription-plan.dart) if the team
-- decides different numbers.
create or replace function public.organizer_plan_limits(p_user_id uuid)
returns table (
  plan_name text,
  max_events_per_month int,
  max_days_multi int,
  max_tickets_per_day int
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_fee numeric;
begin
  select monthly_fee into v_fee
  from public.organizer_subscriptions
  where user_id = p_user_id and status = 'active'
  order by start_date desc
  limit 1;

  if v_fee is null then
    -- No active plan selected: treat as no allowance.
    return query select 'None'::text, 0, 0, 0;
  elsif v_fee >= 1499 then
    return query select 'Premium'::text, null::int, null::int, null::int;
  elsif v_fee >= 699 then
    return query select 'Standard'::text, 9, 14, 5000;
  else
    return query select 'Basic'::text, 3, 3, 500;
  end if;
end;
$$;

grant execute on function public.organizer_plan_limits(uuid) to authenticated;

-- ── Create event (atomic, plan-limited, multi-day aware) ─────────────────
-- p_tiers: jsonb array of {"name": text, "price": number, "quantity": int}
-- Returns the new top-level (parent or single-day) event id.
create or replace function public.create_event_with_days(
  p_title text,
  p_venue text,
  p_description text,
  p_event_type event_type,
  p_start_date date,
  p_end_date date,
  p_status event_status,
  p_tiers jsonb
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_plan record;
  v_total_days int;
  v_events_this_month int;
  v_tickets_per_day int;
  v_parent uuid;
  v_child uuid;
  v_i int;
  v_tier jsonb;
begin
  if v_user is null then
    raise exception 'You need to be signed in to create an event.';
  end if;
  if not public.is_organizer() then
    raise exception 'Only organizer accounts can create events.';
  end if;
  if p_status not in ('draft', 'published') then
    raise exception 'New events can only be created as draft or published.';
  end if;
  if p_event_type = 'multi_day' and (p_end_date is null or p_end_date <= p_start_date) then
    raise exception 'Multi-day events need an end date after the start date.';
  end if;

  select * into v_plan from public.organizer_plan_limits(v_user);

  -- Drafts don't consume the monthly allowance; publishing does.
  if p_status = 'published' and v_plan.max_events_per_month is not null then
    select count(*) into v_events_this_month
    from public.events
    where organizer_id = v_user
      and parent_event_id is null
      and status in ('published', 'completed')
      and date_trunc('month', created_at) = date_trunc('month', now());
    if v_events_this_month >= v_plan.max_events_per_month then
      raise exception 'Your % plan allows % events per month. Upgrade your plan to publish more.',
        v_plan.plan_name, v_plan.max_events_per_month;
    end if;
  end if;

  v_total_days := case when p_event_type = 'multi_day'
                       then (p_end_date - p_start_date) + 1 else 1 end;

  if p_event_type = 'multi_day'
     and v_plan.max_days_multi is not null
     and v_total_days > v_plan.max_days_multi then
    raise exception 'Your % plan allows multi-day events up to % days (you picked %).',
      v_plan.plan_name, v_plan.max_days_multi, v_total_days;
  end if;

  -- Daily ticket cap: every event day carries its own copy of the tiers, so
  -- the cap applies to the sum of tier quantities (per day).
  select coalesce(sum((t->>'quantity')::int), 0) into v_tickets_per_day
  from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) t;

  if v_plan.max_tickets_per_day is not null
     and v_tickets_per_day > v_plan.max_tickets_per_day then
    raise exception 'Your % plan allows up to % tickets per event day (you set %).',
      v_plan.plan_name, v_plan.max_tickets_per_day, v_tickets_per_day;
  end if;

  insert into public.events (
    event_type, organizer_id, title, description, venue, status,
    event_start_date, event_end_date
  )
  values (
    p_event_type, v_user, p_title, nullif(p_description, ''), p_venue, p_status,
    p_start_date, case when p_event_type = 'multi_day' then p_end_date end
  )
  returning event_id into v_parent;

  for v_tier in select * from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) loop
    insert into public.ticket_tiers (event_id, tier_name, base_price, total_quantity, remaining_quantity)
    values (v_parent, v_tier->>'name', (v_tier->>'price')::numeric,
            (v_tier->>'quantity')::int, (v_tier->>'quantity')::int);
  end loop;

  if p_event_type = 'multi_day' then
    for v_i in 0 .. v_total_days - 1 loop
      insert into public.events (
        event_type, parent_event_id, day_number, organizer_id, title,
        description, venue, status, event_start_date
      )
      values (
        'multi_day', v_parent, v_i + 1, v_user,
        p_title || ' — Day ' || (v_i + 1),
        nullif(p_description, ''), p_venue, p_status, p_start_date + v_i
      )
      returning event_id into v_child;

      for v_tier in select * from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) loop
        insert into public.ticket_tiers (event_id, tier_name, base_price, total_quantity, remaining_quantity)
        values (v_child, v_tier->>'name', (v_tier->>'price')::numeric,
                (v_tier->>'quantity')::int, (v_tier->>'quantity')::int);
      end loop;
    end loop;
  end if;

  return v_parent;
end;
$$;

grant execute on function public.create_event_with_days(text, text, text, event_type, date, date, event_status, jsonb) to authenticated;

-- ── Cancel event (whole event or a single day) + refunds + notifications ─
-- p_event_id may be:
--   * a single-day event          -> cancels it
--   * a multi-day parent          -> cancels the parent and every day
--   * a multi-day child (a day)   -> cancels only that day
-- Returns how many tickets were refunded and the total refunded amount.
create or replace function public.cancel_event(
  p_event_id uuid,
  p_reason text default null
)
returns table (tickets_refunded int, amount_refunded numeric)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_event public.events;
  v_target_ids uuid[];
  v_count int := 0;
  v_amount numeric := 0;
  r record;
begin
  if v_user is null then
    raise exception 'You need to be signed in.';
  end if;

  select * into v_event from public.events where event_id = p_event_id;
  if not found then
    raise exception 'That event no longer exists.';
  end if;
  if not (public.is_admin() or (public.is_organizer() and v_event.organizer_id = v_user)) then
    raise exception 'You can only cancel your own events.';
  end if;
  if v_event.status = 'canceled' then
    raise exception 'This event is already canceled.';
  end if;

  select array_agg(event_id) into v_target_ids
  from public.events
  where event_id = p_event_id or parent_event_id = p_event_id;

  update public.events
     set status = 'canceled', canceled_at = now(),
         cancel_reason = nullif(p_reason, ''), updated_at = now()
   where event_id = any (v_target_ids);

  -- If the last active day of a multi-day run was just canceled, cancel the
  -- parent container too so it disappears from browsing.
  if v_event.parent_event_id is not null then
    if not exists (
      select 1 from public.events
      where parent_event_id = v_event.parent_event_id and status <> 'canceled'
    ) then
      update public.events
         set status = 'canceled', canceled_at = now(),
             cancel_reason = nullif(p_reason, ''), updated_at = now()
       where event_id = v_event.parent_event_id;
    end if;
  end if;

  -- Refund + notify every current holder of a not-yet-used ticket.
  for r in
    select t.ticket_id, t.owner_id, e.title,
           (select tr.transaction_id
              from public.transactions tr
             where tr.ticket_id = t.ticket_id and tr.status = 'completed'
             order by tr.created_at desc limit 1) as tx_id,
           (select tr.amount
              from public.transactions tr
             where tr.ticket_id = t.ticket_id and tr.status = 'completed'
             order by tr.created_at desc limit 1) as tx_amount
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e on e.event_id = tt.event_id
     where tt.event_id = any (v_target_ids)
       and t.ticket_status in ('valid', 'listed')
  loop
    update public.tickets
       set ticket_status = 'canceled', qr_status = 'invalidated'
     where ticket_id = r.ticket_id;

    -- Any open resale listing for this ticket is closed as well.
    update public.resale_listings
       set listing_status = 'canceled'
     where ticket_id = r.ticket_id and listing_status = 'active';

    if r.tx_id is not null then
      update public.transactions
         set status = 'refunded', escrow_status = 'refunded'
       where transaction_id = r.tx_id;
      v_amount := v_amount + coalesce(r.tx_amount, 0);
    end if;
    v_count := v_count + 1;

    insert into public.notifications (user_id, title, message, type, channel)
    values (
      r.owner_id,
      'Event canceled',
      '"' || r.title || '" was canceled by the organizer. Your ticket is no longer valid and a refund of ₱'
        || to_char(coalesce(r.tx_amount, 0), 'FM999,999,990.00') || ' has been issued.',
      'ticket', 'in_app'
    );
  end loop;

  return query select v_count, v_amount;
end;
$$;

grant execute on function public.cancel_event(uuid, text) to authenticated;

-- ── Admin: approve / reject an organizer (or any ID review) + notify ─────
create or replace function public.admin_review_account(
  p_user_id uuid,
  p_status id_verification_status,
  p_reason text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_role user_role;
  v_name text;
begin
  if not public.is_admin() then
    raise exception 'Only admins can review accounts.';
  end if;
  if p_status = 'pending' then
    raise exception 'Choose approve or reject.';
  end if;

  update public.users
     set id_verification_status = p_status, updated_at = now()
   where id = p_user_id
   returning role, coalesce(nullif(organization_name, ''), full_name) into v_role, v_name;

  if not found then
    raise exception 'That account no longer exists.';
  end if;

  insert into public.notifications (user_id, title, message, type, channel)
  values (
    p_user_id,
    case when p_status = 'verified' then 'Account approved' else 'Application rejected' end,
    case
      when p_status = 'verified' and v_role = 'organizer'
        then 'Good news, ' || v_name || '! Your organizer account is approved. You can now create events.'
      when p_status = 'verified'
        then 'Your account has been verified. You can now buy tickets.'
      else 'We could not approve your ' ||
           case when v_role = 'organizer' then 'organizer application' else 'account' end ||
           coalesce('. Reason: ' || nullif(p_reason, ''), '. Please re-submit clearer documents.')
    end,
    'system', 'in_app'
  );
end;
$$;

grant execute on function public.admin_review_account(uuid, id_verification_status, text) to authenticated;

-- ── Admin: platform-wide announcement ────────────────────────────────────
-- p_audience: 'all' | 'buyers' | 'organizers'. Only verified, active
-- accounts receive it. Returns how many users were notified.
create or replace function public.send_announcement(
  p_subject text,
  p_message text,
  p_audience text default 'all'
)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'Only admins can send announcements.';
  end if;
  if length(trim(coalesce(p_subject, ''))) = 0 or length(trim(coalesce(p_message, ''))) = 0 then
    raise exception 'Subject and message are required.';
  end if;

  insert into public.notifications (user_id, title, message, type, channel)
  select u.id, trim(p_subject), trim(p_message), 'system', 'in_app'
    from public.users u
   where u.account_status = 'active'
     and u.role <> 'admin'
     and u.id_verification_status = 'verified'
     and (
       p_audience = 'all'
       or (p_audience = 'buyers' and u.role = 'buyer')
       or (p_audience = 'organizers' and u.role = 'organizer')
     );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.send_announcement(text, text, text) to authenticated;

-- ── Organizer: persist edits to an event + its tiers ─────────────────────
-- Replaces the old local-cache-only updateEvent. Tier sold counts are
-- preserved: remaining_quantity = new total - already sold.
create or replace function public.update_event_details(
  p_event_id uuid,
  p_title text,
  p_venue text,
  p_description text,
  p_tiers jsonb,
  p_status event_status default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_event public.events;
  v_plan record;
  v_total int;
  v_ids uuid[];
  v_id uuid;
  v_tier jsonb;
  v_sold int;
begin
  select * into v_event from public.events where event_id = p_event_id;
  if not found then raise exception 'That event no longer exists.'; end if;
  if not (public.is_admin() or (public.is_organizer() and v_event.organizer_id = v_user)) then
    raise exception 'You can only edit your own events.';
  end if;
  if v_event.status = 'canceled' then
    raise exception 'Canceled events cannot be edited.';
  end if;

  select * into v_plan from public.organizer_plan_limits(v_event.organizer_id);
  select coalesce(sum((t->>'quantity')::int), 0) into v_total
    from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) t;
  if v_plan.max_tickets_per_day is not null and v_total > v_plan.max_tickets_per_day then
    raise exception 'Your % plan allows up to % tickets per event day (you set %).',
      v_plan.plan_name, v_plan.max_tickets_per_day, v_total;
  end if;

  -- Publishing a draft counts against the monthly allowance.
  if p_status = 'published' and v_event.status = 'draft'
     and v_plan.max_events_per_month is not null
     and v_event.parent_event_id is null then
    if (select count(*) from public.events
         where organizer_id = v_event.organizer_id and parent_event_id is null
           and status in ('published', 'completed')
           and date_trunc('month', created_at) = date_trunc('month', now()))
       >= v_plan.max_events_per_month then
      raise exception 'Your % plan allows % events per month. Upgrade your plan to publish more.',
        v_plan.plan_name, v_plan.max_events_per_month;
    end if;
  end if;

  select array_agg(event_id) into v_ids
    from public.events
   where event_id = p_event_id or parent_event_id = p_event_id;

  update public.events
     set title = case when event_id = p_event_id then p_title
                      else p_title || ' — Day ' || coalesce(day_number::text, '') end,
         venue = p_venue,
         description = nullif(p_description, ''),
         status = coalesce(p_status, status),
         updated_at = now()
   where event_id = any (v_ids) and status <> 'canceled';

  foreach v_id in array v_ids loop
    for v_tier in select * from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) loop
      select total_quantity - remaining_quantity into v_sold
        from public.ticket_tiers
       where event_id = v_id and tier_name = v_tier->>'name';

      if found then
        if (v_tier->>'quantity')::int < v_sold then
          raise exception 'Tier "%" already sold % tickets — quantity cannot go below that.',
            v_tier->>'name', v_sold;
        end if;
        update public.ticket_tiers
           set base_price = (v_tier->>'price')::numeric,
               total_quantity = (v_tier->>'quantity')::int,
               remaining_quantity = (v_tier->>'quantity')::int - v_sold
         where event_id = v_id and tier_name = v_tier->>'name';
      else
        insert into public.ticket_tiers (event_id, tier_name, base_price, total_quantity, remaining_quantity)
        values (v_id, v_tier->>'name', (v_tier->>'price')::numeric,
                (v_tier->>'quantity')::int, (v_tier->>'quantity')::int);
      end if;
    end loop;

    -- Tiers the organizer removed (only if nothing was sold on them).
    delete from public.ticket_tiers tt
     where tt.event_id = v_id
       and tt.total_quantity = tt.remaining_quantity
       and not exists (
         select 1 from jsonb_array_elements(coalesce(p_tiers, '[]'::jsonb)) t
          where t->>'name' = tt.tier_name
       );
  end loop;
end;
$$;

grant execute on function public.update_event_details(uuid, text, text, text, jsonb, event_status) to authenticated;

-- ── Storage: private bucket for event supporting documents ───────────────
insert into storage.buckets (id, name, public)
values ('event_documents', 'event_documents', false)
on conflict (id) do nothing;

drop policy if exists "event_documents_insert_owning_organizer" on storage.objects;
create policy "event_documents_insert_owning_organizer"
  on storage.objects for insert
  with check (
    bucket_id = 'event_documents'
    and exists (
      select 1 from public.events e
      where e.event_id::text = (storage.foldername(name))[1]
        and e.organizer_id = auth.uid()
    )
  );

drop policy if exists "event_documents_select_owner_or_admin" on storage.objects;
create policy "event_documents_select_owner_or_admin"
  on storage.objects for select
  using (
    bucket_id = 'event_documents'
    and (
      public.is_admin()
      or exists (
        select 1 from public.events e
        where e.event_id::text = (storage.foldername(name))[1]
          and e.organizer_id = auth.uid()
      )
    )
  );

-- ── Realtime: let the organizer Sales screen update after each purchase ──
do $$
begin
  alter publication supabase_realtime add table public.ticket_tiers;
exception
  when duplicate_object then null;  -- already in the publication
  when undefined_object then null;  -- realtime publication not present
end $$;
