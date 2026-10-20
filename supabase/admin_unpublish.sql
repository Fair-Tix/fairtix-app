-- =============================================================================
-- FairTix — admin UNPUBLISH with a compliance deadline.
-- Run AFTER auto_refund.sql and organizer_event_functions.sql. Safe to re-run.
--
-- Flow:
--   1. Organizer publishes an event (it goes live immediately).
--   2. Admin opens the event's supporting documents (Events & Tickets ->
--      Documents). If they are not valid, the admin unpublishes the event
--      with a reason and a number of days to comply.
--   3. Unpublish hides the event from event goers but ERASES nothing
--      (status goes back to 'draft', unpublished_at marks it as an admin
--      unpublish rather than an organizer draft).
--   4. Every current ticket holder is refunded automatically, exactly like a
--      cancellation (the refund trigger below also fires on unpublish).
--   5. The organizer uploads proper documents; the admin republishes.
--      Organizers cannot republish an admin-unpublished event themselves.
--   6. If the deadline passes with no republish, the event is canceled.
-- =============================================================================

alter table public.events
  add column if not exists unpublished_at timestamptz,
  add column if not exists unpublish_reason text,
  add column if not exists compliance_deadline timestamptz;

-- ── Organizers cannot bypass the admin by republishing themselves ───────
create or replace function public.guard_unpublished_republish()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if old.unpublished_at is not null
     and old.status <> 'published'
     and new.status = 'published'
     and not public.is_admin() then
    raise exception
      'This event was unpublished by an admin. Submit the required documents and wait for admin approval.';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_unpublished_republish()
  from public, anon, authenticated;

drop trigger if exists guard_unpublished_republish on public.events;
create trigger guard_unpublished_republish
  before update of status on public.events
  for each row execute procedure public.guard_unpublished_republish();

-- ── Refund trigger: now also fires when an admin unpublishes ────────────
create or replace function public.create_refunds_on_event_cancel()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (new.status = 'canceled' and old.status is distinct from 'canceled')
     or (new.status = 'draft' and old.status = 'published'
         and new.unpublished_at is not null) then

    -- 1. One refund per ticket, for its latest completed payment.
    insert into public.refunds
      (transaction_id, ticket_id, buyer_id, event_id, amount)
    select x.transaction_id, x.ticket_id, x.buyer_id, x.event_id, x.amount
    from (
      select distinct on (tr.ticket_id)
             tr.transaction_id, tr.ticket_id, tr.buyer_id,
             e.event_id, tr.amount
      from public.transactions tr
      join public.tickets t       on t.ticket_id = tr.ticket_id
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e        on e.event_id = tt.event_id
      where (e.event_id = new.event_id or e.parent_event_id = new.event_id)
        and tr.transaction_type::text in ('purchase', 'resale')
        and tr.status::text = 'completed'
        and t.ticket_status::text <> 'used'
      order by tr.ticket_id, tr.created_at desc
    ) x
    on conflict (transaction_id) do nothing;

    -- 2. Cancel active resale listings.
    update public.resale_listings rl
       set listing_status = 'canceled'
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e        on e.event_id = tt.event_id
     where rl.ticket_id = t.ticket_id
       and rl.listing_status::text = 'active'
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id);

    -- 3. Cancel unscanned tickets and kill their QR codes.
    update public.tickets t
       set ticket_status = 'canceled', qr_status = 'invalidated'
      from public.ticket_tiers tt, public.events e
     where tt.tier_id = t.tier_id
       and e.event_id = tt.event_id
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id)
       and t.ticket_status::text <> 'used';

    -- 4. Settle the pending refunds immediately.
    update public.transactions tr
       set status = 'refunded', escrow_status = 'refunded'
      from public.refunds r
     where r.transaction_id = tr.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);

    update public.organizer_fees f
       set status = 'withheld'
      from public.refunds r
     where r.transaction_id = f.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);

    update public.refunds r
       set status = 'processed', processed_at = now()
     where r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);
  end if;
  return new;
end;
$$;

revoke all on function public.create_refunds_on_event_cancel()
  from public, anon, authenticated;

drop trigger if exists on_event_cancel_create_refunds on public.events;
create trigger on_event_cancel_create_refunds
  after update of status on public.events
  for each row execute procedure public.create_refunds_on_event_cancel();

-- ── Admin: unpublish (hide, refund, set compliance deadline) ────────────
create or replace function public.admin_unpublish_event(
  p_event_id uuid,
  p_reason text,
  p_deadline_days integer default 7
)
returns table(tickets_refunded integer, amount_refunded numeric)
language plpgsql
security definer set search_path = public
as $$
declare
  v_event public.events%rowtype;
  v_ticket_count integer;
  v_amount numeric;
  v_deadline timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Only admins can unpublish events.';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'Give the organizer a reason for unpublishing.';
  end if;
  if p_deadline_days is null or p_deadline_days < 1 or p_deadline_days > 30 then
    raise exception 'The compliance period must be between 1 and 30 days.';
  end if;

  select * into v_event from public.events
   where event_id = p_event_id for update;
  if not found then
    raise exception 'This event could not be found.';
  end if;
  if v_event.parent_event_id is not null then
    raise exception 'Unpublish a multi-day event from its parent event.';
  end if;
  if v_event.status <> 'published' then
    raise exception 'Only published events can be unpublished.';
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
    and (e.event_id = p_event_id or e.parent_event_id = p_event_id);

  v_deadline := now() + make_interval(days => p_deadline_days);

  -- Children first so the parent row's trigger sees them already hidden.
  update public.events
     set status = 'draft',
         unpublished_at = now(),
         unpublish_reason = btrim(p_reason),
         compliance_deadline = v_deadline,
         updated_at = now()
   where (event_id = p_event_id or parent_event_id = p_event_id)
     and status = 'published';

  perform public.notify_user(
    v_event.organizer_id,
    'Event unpublished',
    '"' || v_event.title || '" was unpublished by an admin: ' || btrim(p_reason)
      || '. Upload valid supporting documents before '
      || to_char(v_deadline, 'Mon DD, YYYY')
      || ' or the event will be canceled. Ticket holders have been refunded.',
    'system'
  );

  return query select v_ticket_count, v_amount;
end;
$$;

revoke all on function public.admin_unpublish_event(uuid, text, integer)
  from public, anon;
grant execute on function public.admin_unpublish_event(uuid, text, integer)
  to authenticated;

-- ── Admin: republish after the organizer complied ───────────────────────
create or replace function public.admin_republish_event(p_event_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_event public.events%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only admins can republish events.';
  end if;
  select * into v_event from public.events
   where event_id = p_event_id for update;
  if not found or v_event.parent_event_id is not null then
    raise exception 'This event could not be found.';
  end if;
  if v_event.status <> 'draft' or v_event.unpublished_at is null then
    raise exception 'This event is not waiting for compliance.';
  end if;

  update public.events
     set status = 'published',
         unpublished_at = null,
         unpublish_reason = null,
         compliance_deadline = null,
         updated_at = now()
   where (event_id = p_event_id or parent_event_id = p_event_id)
     and status = 'draft'
     and unpublished_at is not null;

  perform public.notify_user(
    v_event.organizer_id,
    'Event republished',
    '"' || v_event.title || '" was approved and is live again.',
    'system'
  );
end;
$$;

revoke all on function public.admin_republish_event(uuid) from public, anon;
grant execute on function public.admin_republish_event(uuid) to authenticated;

-- ── Deadline lapsed -> cancel (idempotent; called on admin refresh) ─────
create or replace function public.cancel_lapsed_unpublished_events()
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.events
  where parent_event_id is null
    and status = 'draft'
    and unpublished_at is not null
    and compliance_deadline < now();

  update public.events e
     set status = 'canceled', updated_at = now()
   where e.status = 'draft'
     and e.unpublished_at is not null
     and (
       e.compliance_deadline < now()
       or exists (
         select 1 from public.events p
          where p.event_id = e.parent_event_id
            and p.compliance_deadline < now())
     );

  return v_count;
end;
$$;

revoke all on function public.cancel_lapsed_unpublished_events()
  from public, anon;
grant execute on function public.cancel_lapsed_unpublished_events()
  to authenticated;

-- ── Tell admins when an unpublished event gets new documents ───────────
-- Same as append_event_document in organizer_event_functions.sql, plus an
-- admin notification when the event is waiting for compliance.
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
  v_title text;
  v_unpublished timestamptz;
  v_admin uuid;
begin
  select organizer_id, title, unpublished_at
    into v_owner, v_title, v_unpublished
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

  if v_unpublished is not null then
    for v_admin in select id from public.users where role = 'admin'
    loop
      perform public.notify_user(
        v_admin,
        'New documents submitted',
        'The organizer uploaded new documents for "' || v_title
          || '". Review them in Events & Tickets and republish if valid.',
        'system'
      );
    end loop;
  end if;
end;
$$;

revoke all on function public.append_event_document(uuid, text)
  from public, anon;
grant execute on function public.append_event_document(uuid, text)
  to authenticated;
