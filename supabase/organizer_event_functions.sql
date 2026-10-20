-- =============================================================================
-- FairTix — organizer event operations and admin RPCs.
-- Apply after schema.sql, policies.sql, notification_functions.sql, and
-- refund_functions.sql. Safe to re-run.
-- =============================================================================

alter table public.events
  add column if not exists supporting_document_urls text[] not null default '{}';

insert into storage.buckets (id, name, public)
values ('event_documents', 'event_documents', false)
on conflict (id) do nothing;

drop policy if exists "event_documents_select_owner_or_admin" on storage.objects;
create policy "event_documents_select_owner_or_admin"
  on storage.objects for select
  using (
    bucket_id = 'event_documents'
    and (
      public.is_admin()
      or exists (
        select 1
        from public.events e
        where e.event_id::text = (storage.foldername(name))[1]
          and e.organizer_id = auth.uid()
      )
    )
  );

drop policy if exists "event_documents_insert_owner" on storage.objects;
create policy "event_documents_insert_owner"
  on storage.objects for insert
  with check (
    bucket_id = 'event_documents'
    and exists (
      select 1
      from public.events e
      where e.event_id::text = (storage.foldername(name))[1]
        and e.organizer_id = auth.uid()
    )
  );

drop policy if exists "event_documents_update_owner" on storage.objects;
create policy "event_documents_update_owner"
  on storage.objects for update
  using (
    bucket_id = 'event_documents'
    and exists (
      select 1
      from public.events e
      where e.event_id::text = (storage.foldername(name))[1]
        and e.organizer_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'event_documents'
    and exists (
      select 1
      from public.events e
      where e.event_id::text = (storage.foldername(name))[1]
        and e.organizer_id = auth.uid()
    )
  );

-- Organizer writes must go through the RPCs below so table writes cannot
-- bypass the plan limits. Attachment metadata is written through its own
-- narrowly-scoped RPCs after the Storage upload succeeds.
drop policy if exists "events_insert_own_organizer" on public.events;
drop policy if exists "events_insert_admin_only" on public.events;
create policy "events_insert_admin_only"
  on public.events for insert
  with check (public.is_admin());
drop policy if exists "events_update_own_or_admin" on public.events;
drop policy if exists "events_update_admin_only" on public.events;
create policy "events_update_admin_only"
  on public.events for update
  using (public.is_admin())
  with check (public.is_admin());
drop policy if exists "ticket_tiers_write_owning_organizer_or_admin"
  on public.ticket_tiers;
drop policy if exists "ticket_tiers_admin_write_only" on public.ticket_tiers;
create policy "ticket_tiers_admin_write_only"
  on public.ticket_tiers for all
  using (public.is_admin())
  with check (public.is_admin());

create table if not exists public.organizer_event_monthly_usage (
  organizer_id uuid not null references public.users(id) on delete cascade,
  month_start date not null,
  event_count integer not null default 0 check (event_count >= 0),
  primary key (organizer_id, month_start)
);
alter table public.organizer_event_monthly_usage enable row level security;
revoke all on public.organizer_event_monthly_usage from public, anon, authenticated;

insert into public.organizer_event_monthly_usage (
  organizer_id, month_start, event_count
)
select e.organizer_id,
       date_trunc('month', e.created_at)::date,
       count(*)::integer
from public.events e
where e.parent_event_id is null
group by e.organizer_id, date_trunc('month', e.created_at)::date
on conflict (organizer_id, month_start) do update
set event_count = greatest(
  public.organizer_event_monthly_usage.event_count,
  excluded.event_count
);

create or replace function public._organizer_plan_fee(p_user_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select s.monthly_fee
  from public.organizer_subscriptions s
  where s.user_id = p_user_id
    and s.status = 'active'
    and current_date between s.start_date and s.end_date
  order by s.start_date desc, s.created_at desc
  limit 1;
$$;

revoke all on function public._organizer_plan_fee(uuid)
  from public, anon, authenticated;

create or replace function public._check_event_tiers(
  p_event_id uuid,
  p_tiers jsonb,
  p_daily_ticket_cap integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier jsonb;
  v_name text;
  v_price numeric;
  v_quantity integer;
  v_tier_id uuid;
  v_sold integer;
  v_total integer;
  v_existing record;
begin
  if coalesce(jsonb_typeof(p_tiers), '') <> 'array' then
    raise exception 'Ticket tiers must be a list.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_tiers) as items(value)
    group by lower(btrim(items.value->>'name'))
    having count(*) > 1
  ) then
    raise exception 'Each ticket tier must have a different name.';
  end if;

  select coalesce(sum((items.value->>'quantity')::integer), 0)
    into v_total
  from jsonb_array_elements(p_tiers) as items(value);
  if p_daily_ticket_cap is not null and v_total > p_daily_ticket_cap then
    raise exception 'This plan allows up to % tickets per event day.',
      p_daily_ticket_cap;
  end if;

  for v_tier in select value from jsonb_array_elements(p_tiers)
  loop
    v_name := btrim(v_tier->>'name');
    v_price := (v_tier->>'price')::numeric;
    v_quantity := (v_tier->>'quantity')::integer;

    if v_name = '' or v_price < 0 or v_quantity <= 0 then
      raise exception 'Ticket tier name, price, or quantity is invalid.';
    end if;

    select tt.tier_id, tt.total_quantity - tt.remaining_quantity
      into v_tier_id, v_sold
    from public.ticket_tiers tt
    where tt.event_id = p_event_id and lower(tt.tier_name) = lower(v_name)
    for update;

    if found then
      if v_quantity < v_sold then
        raise exception 'Tier "%" cannot be reduced below its sold quantity (%).',
          v_name, v_sold;
      end if;
      update public.ticket_tiers
      set tier_name = v_name,
          base_price = v_price,
          total_quantity = v_quantity,
          remaining_quantity = v_quantity - v_sold
      where tier_id = v_tier_id;
    else
      insert into public.ticket_tiers (
        event_id, tier_name, base_price, total_quantity, remaining_quantity
      )
      values (p_event_id, v_name, v_price, v_quantity, v_quantity);
    end if;
  end loop;

  for v_existing in
    select tt.tier_id, tt.tier_name
    from public.ticket_tiers tt
    where tt.event_id = p_event_id
      and not exists (
        select 1
        from jsonb_array_elements(p_tiers) as items(value)
        where lower(btrim(items.value->>'name')) = lower(tt.tier_name)
      )
    for update
  loop
    if exists (
      select 1 from public.tickets t where t.tier_id = v_existing.tier_id
    ) then
      raise exception 'Tier "%" has issued tickets and cannot be removed.',
        v_existing.tier_name;
    end if;
    delete from public.ticket_tiers where tier_id = v_existing.tier_id;
  end loop;
end;
$$;

revoke all on function public._check_event_tiers(uuid, jsonb, integer)
  from public, anon, authenticated;

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
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_user public.users%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_monthly_limit integer;
  v_day_limit integer;
  v_ticket_cap integer;
  v_day_count integer;
  v_month_start date := date_trunc('month', now())::date;
  v_parent_id uuid;
  v_day_id uuid;
  v_day date;
  v_day_number integer := 0;
begin
  if v_user_id is null then
    raise exception 'You need to be signed in to create an event.';
  end if;
  select * into v_user from public.users where id = v_user_id;
  if not found or v_user.role <> 'organizer'
     or v_user.id_verification_status <> 'verified'
     or v_user.account_status <> 'active' then
    raise exception 'Only approved, active organizers can create events.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select * into v_plan from public._organizer_plan(v_user_id);
  if v_plan.plan_id is null then
    raise exception 'Choose an active subscription plan before creating events.';
  end if;

  -- Limits come from the plan the admin configured in Platform Settings
  -- (public.subscription_plans); a null limit means unlimited.
  v_monthly_limit := v_plan.max_events_per_month;
  v_day_limit := v_plan.max_multiday_days;
  v_ticket_cap := v_plan.max_tickets_per_day;

  insert into public.organizer_event_monthly_usage (
    organizer_id, month_start, event_count
  )
  values (v_user_id, v_month_start, 0)
  on conflict (organizer_id, month_start) do nothing;
  perform 1
  from public.organizer_event_monthly_usage u
  where u.organizer_id = v_user_id and u.month_start = v_month_start
  for update;

  if v_monthly_limit is not null and exists (
    select 1
    from public.organizer_event_monthly_usage u
    where u.organizer_id = v_user_id
      and u.month_start = v_month_start
      and u.event_count >= v_monthly_limit
  ) then
    raise exception 'Your plan allows % events per month.', v_monthly_limit;
  end if;

  if p_title is null or btrim(p_title) = ''
     or p_venue is null or btrim(p_venue) = ''
     or p_start_date is null then
    raise exception 'Event name, date, and venue are required.';
  end if;
  if p_status not in ('draft', 'published') then
    raise exception 'New events can only be created as drafts or published events.';
  end if;
  if p_start_date < current_date then
    raise exception 'Event dates cannot be in the past.';
  end if;

  if p_event_type = 'multi_day' then
    if p_end_date is null or p_end_date <= p_start_date then
      raise exception 'Multi-day events need an end date after the start date.';
    end if;
    v_day_count := p_end_date - p_start_date + 1;
    if v_day_limit is not null and v_day_count > v_day_limit then
      raise exception 'Your plan allows multi-day events up to % days.',
        v_day_limit;
    end if;
  else
    if p_end_date is not null and p_end_date <> p_start_date then
      raise exception 'A single-day event cannot have a different end date.';
    end if;
    v_day_count := 1;
  end if;

  if p_status = 'published' and coalesce(jsonb_array_length(p_tiers), 0) = 0 then
    raise exception 'Add at least one ticket tier before publishing.';
  end if;

  insert into public.events (
    event_type, event_start_date, event_end_date, organizer_id,
    title, description, venue, status
  )
  values (
    p_event_type, p_start_date,
    case when p_event_type = 'multi_day' then p_end_date else null end,
    v_user_id, btrim(p_title), nullif(btrim(p_description), ''),
    btrim(p_venue), p_status
  )
  returning event_id into v_parent_id;
  update public.organizer_event_monthly_usage
  set event_count = event_count + 1
  where organizer_id = v_user_id and month_start = v_month_start;

  if p_event_type = 'single_day' then
    perform public._check_event_tiers(v_parent_id, p_tiers, v_ticket_cap);
  else
    for v_day in
      select generated_day::date
      from generate_series(
        p_start_date::timestamp,
        p_end_date::timestamp,
        interval '1 day'
      ) as generated_day
    loop
      v_day_number := v_day_number + 1;
      insert into public.events (
        event_type, parent_event_id, day_number, event_start_date,
        event_end_date, organizer_id, title, description, venue, status
      )
      values (
        'single_day', v_parent_id, v_day_number, v_day, null,
        v_user_id, btrim(p_title), nullif(btrim(p_description), ''),
        btrim(p_venue), p_status
      )
      returning event_id into v_day_id;
      perform public._check_event_tiers(v_day_id, p_tiers, v_ticket_cap);
    end loop;
  end if;

  return v_parent_id;
end;
$$;

revoke all on function public.create_event_with_days(
  text, text, text, event_type, date, date, event_status, jsonb
) from public, anon;
grant execute on function public.create_event_with_days(
  text, text, text, event_type, date, date, event_status, jsonb
) to authenticated;

create or replace function public.set_event_banner(
  p_event_id uuid,
  p_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select organizer_id into v_owner
  from public.events
  where event_id = p_event_id and parent_event_id is null
  for update;
  if not found or auth.uid() is distinct from v_owner then
    raise exception 'You are not allowed to update this event banner.';
  end if;
  if p_path is null or p_path not like p_event_id::text || '/%' then
    raise exception 'The event banner path is invalid.';
  end if;

  update public.events
  set banner_image_url = p_path, updated_at = now()
  where event_id = p_event_id or parent_event_id = p_event_id;
end;
$$;

revoke all on function public.set_event_banner(uuid, text)
  from public, anon;
grant execute on function public.set_event_banner(uuid, text)
  to authenticated;

create or replace function public.append_event_document(
  p_event_id uuid,
  p_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select organizer_id into v_owner
  from public.events
  where event_id = p_event_id and parent_event_id is null
  for update;
  if not found or auth.uid() is distinct from v_owner then
    raise exception 'You are not allowed to update this event document.';
  end if;
  if p_path is null or p_path not like p_event_id::text || '/%' then
    raise exception 'The event document path is invalid.';
  end if;

  update public.events
  set supporting_document_urls =
        array_append(supporting_document_urls, p_path),
      updated_at = now()
  where event_id = p_event_id or parent_event_id = p_event_id;
end;
$$;

revoke all on function public.append_event_document(uuid, text)
  from public, anon;
grant execute on function public.append_event_document(uuid, text)
  to authenticated;

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
security definer
set search_path = public
as $$
declare
  v_event public.events%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_ticket_cap integer;
  v_day_id uuid;
begin
  select * into v_event
  from public.events
  where event_id = p_event_id
  for update;
  if not found then
    raise exception 'This event could not be found.';
  end if;
  if auth.uid() is null or (
    not public.is_admin() and v_event.organizer_id <> auth.uid()
  ) then
    raise exception 'You are not allowed to edit this event.';
  end if;
  if v_event.parent_event_id is not null then
    raise exception 'Edit a multi-day event from its parent event.';
  end if;
  if v_event.status in ('canceled', 'completed') then
    raise exception 'Canceled or completed events cannot be edited.';
  end if;
  if p_title is null or btrim(p_title) = ''
     or p_venue is null or btrim(p_venue) = '' then
    raise exception 'Event name and venue are required.';
  end if;
  if p_status is not null and p_status not in ('draft', 'published') then
    raise exception 'An event can only be saved as a draft or published.';
  end if;
  if p_status = 'published'
     and coalesce(cardinality(v_event.supporting_document_urls), 0) = 0 then
    raise exception 'Upload at least one supporting document before publishing.';
  end if;

  select * into v_plan from public._organizer_plan(v_event.organizer_id);
  if v_plan.plan_id is null then
    raise exception 'Choose an active subscription plan before editing events.';
  end if;
  v_ticket_cap := v_plan.max_tickets_per_day;
  if v_event.event_type = 'multi_day'
     and v_plan.max_multiday_days is not null
     and (v_event.event_end_date - v_event.event_start_date + 1)
         > v_plan.max_multiday_days then
    raise exception 'Your plan allows multi-day events up to % days.',
      v_plan.max_multiday_days;
  end if;

  if v_event.event_type = 'multi_day' then
    for v_day_id in
      select e.event_id
      from public.events e
      where e.parent_event_id = p_event_id and e.status <> 'canceled'
      order by e.day_number
      for update
    loop
      perform public._check_event_tiers(v_day_id, p_tiers, v_ticket_cap);
    end loop;
  else
    perform public._check_event_tiers(p_event_id, p_tiers, v_ticket_cap);
  end if;

  update public.events
  set title = btrim(p_title),
      venue = btrim(p_venue),
      description = nullif(btrim(p_description), ''),
      status = coalesce(p_status, status),
      updated_at = now()
  where event_id = p_event_id or parent_event_id = p_event_id;
end;
$$;

revoke all on function public.update_event_details(
  uuid, text, text, text, jsonb, event_status
) from public, anon;
grant execute on function public.update_event_details(
  uuid, text, text, text, jsonb, event_status
) to authenticated;

create or replace function public.cancel_event(
  p_event_id uuid,
  p_reason text default null
)
returns table(tickets_refunded integer, amount_refunded numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events%rowtype;
  v_ticket_count integer;
  v_amount numeric;
begin
  select * into v_event
  from public.events
  where event_id = p_event_id
  for update;
  if not found then
    raise exception 'This event could not be found.';
  end if;
  if auth.uid() is null or (
    not public.is_admin() and v_event.organizer_id <> auth.uid()
  ) then
    raise exception 'You are not allowed to cancel this event.';
  end if;
  if v_event.status in ('canceled', 'completed') then
    raise exception 'This event is already canceled or completed.';
  end if;

  select count(distinct t.ticket_id), coalesce(sum(tr.amount), 0)
    into v_ticket_count, v_amount
  from public.tickets t
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e on e.event_id = tt.event_id
  join public.transactions tr
    on tr.ticket_id = t.ticket_id
   and tr.transaction_type = 'purchase'
   and tr.status = 'completed'
  where t.ticket_status <> 'used'
    and (
      e.event_id = p_event_id
      or (v_event.parent_event_id is null and e.parent_event_id = p_event_id)
    );

  update public.events
  set status = 'canceled', updated_at = now()
  where event_id = p_event_id;

  if v_event.parent_event_id is null then
    update public.events
    set status = 'canceled', updated_at = now()
    where parent_event_id = p_event_id
      and status not in ('canceled', 'completed');
  end if;

  return query select v_ticket_count, v_amount;
end;
$$;

revoke all on function public.cancel_event(uuid, text) from public, anon;
grant execute on function public.cancel_event(uuid, text) to authenticated;

create or replace function public.admin_review_account(
  p_user_id uuid,
  p_status id_verification_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can review accounts.';
  end if;
  if p_status not in ('verified', 'rejected') then
    raise exception 'Review status must be verified or rejected.';
  end if;

  update public.users
  set id_verification_status = p_status,
      updated_at = now()
  where id = p_user_id;
  if not found then
    raise exception 'The account could not be found.';
  end if;
end;
$$;

revoke all on function public.admin_review_account(
  uuid, id_verification_status, text
) from public, anon;
grant execute on function public.admin_review_account(
  uuid, id_verification_status, text
) to authenticated;

create or replace function public.send_announcement(
  p_subject text,
  p_message text,
  p_audience text default 'all'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user record;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Only admins can send platform announcements.';
  end if;
  if p_audience not in ('all', 'buyers', 'organizers') then
    raise exception 'Announcement audience is invalid.';
  end if;
  if btrim(coalesce(p_subject, '')) = ''
     or btrim(coalesce(p_message, '')) = '' then
    raise exception 'Announcement subject and message are required.';
  end if;

  for v_user in
    select u.id
    from public.users u
    where u.id_verification_status = 'verified'
      and u.account_status = 'active'
      and u.role in ('buyer', 'organizer')
      and (
        p_audience = 'all'
        or (p_audience = 'buyers' and u.role = 'buyer')
        or (p_audience = 'organizers' and u.role = 'organizer')
      )
  loop
    perform public.notify_user(
      v_user.id,
      btrim(p_subject),
      btrim(p_message),
      'promo'
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.send_announcement(text, text, text)
  from public, anon;
grant execute on function public.send_announcement(text, text, text)
  to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'ticket_tiers'
     ) then
    alter publication supabase_realtime add table public.ticket_tiers;
  end if;
end;
$$;
