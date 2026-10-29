-- =============================================================================
-- FairTix — Organizer tools: announcements + "my live scanner sessions".
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- scanner_functions.sql and notification_functions.sql.
-- Safe to re-run: everything below is `create or replace`.
--
--   1. send_organizer_announcement(subject, message)
--        An approved organizer with a current subscription sends a promo
--        notification (in-app + email + push) to everyone who holds or has
--        used a ticket to one of their events. Returns how many people it
--        went to.
--   2. list_my_scanner_sessions()
--        The organizer's still-live scanner sessions, so the Scanner page can
--        show (and revoke) them again after the organizer leaves the page.
-- =============================================================================

-- ── 1. Announcements ─────────────────────────────────────────────────────
create or replace function public.send_organizer_announcement(
  p_subject text,
  p_message text
)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_subject text := btrim(coalesce(p_subject, ''));
  v_message text := btrim(coalesce(p_message, ''));
  v_holder record;
  v_count integer := 0;
begin
  if v_uid is null then
    raise exception 'You need to be signed in to send an announcement.';
  end if;

  if not exists (
    select 1 from public.users u
    where u.id = v_uid
      and u.role = 'organizer'
      and u.id_verification_status = 'verified'
  ) then
    raise exception 'Only approved organizers can send announcements.';
  end if;

  if not exists (
    select 1 from public.organizer_subscriptions s
    where s.user_id = v_uid
      and s.status = 'active'
      and current_date between s.start_date and s.end_date
  ) then
    raise exception 'An active subscription is required to send announcements.';
  end if;

  if v_subject = '' or v_message = '' then
    raise exception 'Please write both a subject and a message.';
  end if;
  if char_length(v_subject) > 120 then
    raise exception 'The subject can be at most 120 characters.';
  end if;
  if char_length(v_message) > 500 then
    raise exception 'The message can be at most 500 characters.';
  end if;

  -- Everyone who bought (or was resold) a ticket to any of this organizer's
  -- events, including the day-rows of multi-day events. Canceled tickets are
  -- skipped. Each person is notified once.
  for v_holder in
    select distinct t.owner_id
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where e.organizer_id = v_uid
      and t.ticket_status <> 'canceled'
      and t.owner_id <> v_uid
  loop
    perform public.notify_user(
      v_holder.owner_id,
      v_subject,
      v_message,
      'promo',
      true,
      true
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.send_organizer_announcement(text, text) from public, anon;
grant execute on function public.send_organizer_announcement(text, text) to authenticated;

-- ── 2. The organizer's live scanner sessions ─────────────────────────────
create or replace function public.list_my_scanner_sessions()
returns table (
  session_id uuid,
  event_id uuid,
  event_title text,
  session_pin text,
  session_token text,
  created_at timestamptz,
  expires_at timestamptz
)
language sql
stable
security definer set search_path = public
as $$
  select s.session_id,
         s.event_id,
         e.title,
         s.session_pin,
         s.session_token,
         s.created_at::timestamptz,
         s.expires_at
  from public.scanner_sessions s
  join public.events e on e.event_id = s.event_id
  where s.organizer_id = auth.uid()
    and s.status = 'active'
    and s.expires_at > now()
  order by s.created_at desc;
$$;

revoke all on function public.list_my_scanner_sessions() from public, anon;
grant execute on function public.list_my_scanner_sessions() to authenticated;
