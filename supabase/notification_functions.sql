-- =============================================================================
-- FairTix — Notification generation (in-app + email), driven by database
-- triggers so EVERY path that causes an event notifies — the app, the
-- PayMongo webhook, an admin action in the dashboard, or a manual edit.
-- Run this in the Supabase SQL Editor AFTER schema.sql and policies.sql.
-- Safe to re-run.
--
-- Why this file exists (2026-10-09 system test, Notification Management):
--   * "Sent for OTP, purchase, resale listing and sale, cancellation, and
--     refund" failed because nothing ever wrote to public.notifications —
--     the app only showed a local, always-empty list.
--   * "Emails arrive" / "works for all three roles" failed for the same
--     reason: no notification rows existed to email.
--
-- HOW IT WORKS
--   notify_user() writes TWO rows for one event: channel 'in_app' (shown in
--   the app's notification feed) and channel 'email' (picked up by the
--   send-notification-email Edge Function through a Database Webhook — see
--   supabase/functions/send-notification-email/index.ts for the one-time
--   setup). The app's feed only ever reads the 'in_app' rows.
--
--   Notifications go to a user_id, whatever their role — so event goers,
--   organizers and admins all get them (e.g. organizer: new sale, event
--   canceled, application approved; admin: new organizer application).
-- =============================================================================

create index if not exists notifications_user_channel_read_idx
  on public.notifications (user_id, channel, is_read);

-- ── Helper: write the in-app row (+ optional email row) ──────────────────
-- Only the trigger functions below call this; nobody can invoke it from
-- the client (a user must not be able to mint notifications for others).
create or replace function public.notify_user(
  p_user_id uuid,
  p_title text,
  p_message text,
  p_type notification_type,
  p_send_email boolean default true
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;

  insert into public.notifications (user_id, title, message, type, channel)
  values (p_user_id, p_title, p_message, p_type, 'in_app');

  if p_send_email then
    insert into public.notifications (user_id, title, message, type, channel)
    values (p_user_id, p_title, p_message, p_type, 'email');
  end if;
end;
$$;

revoke all on function public.notify_user(uuid, text, text, notification_type, boolean)
  from public, anon, authenticated;

-- ── 1. Signup (OTP) ──────────────────────────────────────────────────────
-- Supabase Auth itself emails the 6-digit code, so no second email here —
-- only the in-app note, which the user sees once they're signed in.
create or replace function public.trg_notify_signup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.notify_user(
    new.id,
    'Verification code sent',
    'We sent a 6-digit verification code to ' || new.email || '. Enter it to finish setting up your account.',
    'system',
    false
  );
  return new;
end;
$$;

drop trigger if exists notify_on_user_signup on public.users;
create trigger notify_on_user_signup
  after insert on public.users
  for each row execute procedure public.trg_notify_signup();

-- ── 2. Account activated / rejected + new organizer application ──────────
-- Fires when an admin flips id_verification_status (Admin → Accounts /
-- Organizer Applications), and when an organizer finishes uploading their
-- proof documents (which is when admins need to hear about it).
create or replace function public.trg_notify_user_review()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin record;
begin
  if new.id_verification_status is distinct from old.id_verification_status then
    if new.id_verification_status = 'verified' then
      if new.role = 'organizer' then
        perform public.notify_user(
          new.id,
          'Organizer application approved',
          'Your organizer account has been approved. Choose a subscription plan to start creating events.',
          'system'
        );
      else
        perform public.notify_user(
          new.id,
          'Account activated',
          'Your account has been verified. You can now browse events and buy tickets.',
          'system'
        );
      end if;
    elsif new.id_verification_status = 'rejected' then
      perform public.notify_user(
        new.id,
        case when new.role = 'organizer' then 'Organizer application rejected' else 'Verification rejected' end,
        'We could not verify the documents you submitted. Please review them and submit again.',
        'system'
      );
    end if;
  end if;

  -- Organizer finished uploading BOTH proof documents → tell every admin.
  if new.role = 'organizer'
     and new.venue_proof_url is not null
     and new.event_permit_url is not null
     and (old.venue_proof_url is null or old.event_permit_url is null) then
    for v_admin in
      select u.id from public.users u
      where u.role = 'admin' and u.account_status = 'active'
    loop
      perform public.notify_user(
        v_admin.id,
        'New organizer application',
        coalesce(nullif(new.organization_name, ''), new.full_name)
          || ' submitted documents for review.',
        'system'
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists notify_on_user_review on public.users;
create trigger notify_on_user_review
  after update of id_verification_status, venue_proof_url, event_permit_url on public.users
  for each row execute procedure public.trg_notify_user_review();

-- ── 3. Purchase, resale sale, and refund (transactions) ──────────────────
-- Catches the purchase created by purchase_functions.sql (client tap or
-- PayMongo webhook — both end in the same INSERT), the resale sale, and a
-- refund (status flipping to 'refunded').
create or replace function public.trg_notify_transaction()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_old_status text := null;
  v_title text;
  v_organizer uuid;
begin
  if tg_op = 'UPDATE' then
    v_old_status := old.status::text;
  end if;

  select e.title, e.organizer_id
    into v_title, v_organizer
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  v_title := coalesce(v_title, 'the event');

  if new.status = 'completed' and v_old_status is distinct from 'completed' then
    if new.transaction_type = 'purchase' then
      perform public.notify_user(
        new.buyer_id,
        'Ticket purchased',
        'Your ticket for ' || v_title || ' is confirmed. You can find it under My Tickets.',
        'ticket'
      );
      perform public.notify_user(
        v_organizer,
        'New ticket sale',
        'A ticket for ' || v_title || ' was just sold.',
        'ticket'
      );
    elsif new.transaction_type = 'resale' then
      perform public.notify_user(
        new.seller_id,
        'Your ticket was sold',
        'Your resale ticket for ' || v_title || ' has been purchased.',
        'resale'
      );
      perform public.notify_user(
        new.buyer_id,
        'Resale ticket purchased',
        'Your ticket for ' || v_title || ' is confirmed. You can find it under My Tickets.',
        'ticket'
      );
    end if;
  elsif new.status = 'refunded' and v_old_status is distinct from 'refunded' then
    perform public.notify_user(
      new.buyer_id,
      'Refund issued',
      'Your payment of PHP ' || to_char(new.amount, 'FM999,999,990.00')
        || ' for ' || v_title || ' has been refunded.',
      'ticket'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_on_transaction on public.transactions;
create trigger notify_on_transaction
  after insert or update of status on public.transactions
  for each row execute procedure public.trg_notify_transaction();

-- ── 4. Ticket listed for resale ──────────────────────────────────────────
create or replace function public.trg_notify_resale_listing()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_title text;
begin
  select e.title
    into v_title
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  perform public.notify_user(
    new.seller_id,
    'Ticket listed for resale',
    'Your ticket for ' || coalesce(v_title, 'the event') || ' is now listed at PHP '
      || to_char(new.listing_price, 'FM999,999,990.00') || '.',
    'resale'
  );
  return new;
end;
$$;

drop trigger if exists notify_on_resale_listing on public.resale_listings;
create trigger notify_on_resale_listing
  after insert on public.resale_listings
  for each row execute procedure public.trg_notify_resale_listing();

-- ── 5. Event canceled ────────────────────────────────────────────────────
-- Fires from ANY cancel path (organizer, admin, or a manual edit), so
-- ticket holders are always told. Holders of any day of a canceled
-- multi-day event are covered too. The refund itself is a separate step —
-- it sends its own "Refund issued" notice (section 3) when it completes.
create or replace function public.trg_notify_event_canceled()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_holder record;
begin
  if new.status <> 'canceled' or old.status = 'canceled' then
    return new;
  end if;

  -- When a whole multi-day event is canceled, its day-rows usually flip
  -- too; the parent's own notice already covers everyone, so skip a day
  -- whose parent is already canceled to avoid duplicate messages.
  if new.parent_event_id is not null and exists (
    select 1 from public.events p
    where p.event_id = new.parent_event_id and p.status = 'canceled'
  ) then
    return new;
  end if;

  -- Confirmation to the organizer (once per event, not per day-row).
  if new.parent_event_id is null then
    perform public.notify_user(
      new.organizer_id,
      'Event canceled',
      '"' || new.title || '" has been canceled. Ticket holders have been notified.',
      'system'
    );
  end if;

  for v_holder in
    select distinct t.owner_id
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where (e.event_id = new.event_id or e.parent_event_id = new.event_id)
      and t.ticket_status in ('valid', 'listed')
  loop
    perform public.notify_user(
      v_holder.owner_id,
      'Event canceled',
      '"' || new.title || '" has been canceled. You''ll get another notification once your refund is processed.',
      'ticket'
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_on_event_canceled on public.events;
create trigger notify_on_event_canceled
  after update of status on public.events
  for each row execute procedure public.trg_notify_event_canceled();
