-- =============================================================================
-- FairTix — Scanner session, live QR entry-validation, and QR
-- invalidation/reissuance RPCs.
-- Run this in the Supabase SQL Editor AFTER schema.sql and policies.sql.
--
-- Covers roadmap items 24 (Generate Scanner Link), 25/26 (Staff PIN entry +
-- QR Scan Accepted/Rejected results), and 27 (QR invalidation & reissuance).
--
-- Design note: entry staff are handed a link + 4-digit PIN by the
-- organizer — they do NOT need their own FairTix account/login. So
-- `validate_scanner_session` and `scan_ticket` below are SECURITY DEFINER
-- functions grantable to `anon`, keyed on knowing the session's token+PIN
-- rather than on `auth.uid()`. This mirrors how a physical wristband
-- scanner works: whoever holds the link+PIN can scan for that event, no
-- more, no less.
-- =============================================================================

-- ── 1. Generate a scanner session (organizer only) ──────────────────────
-- Roadmap item 24. Creates a fresh session_token + 4-digit session_pin for
-- one event, valid for 12 hours. Only the organizer who owns [p_event_id]
-- (or an admin) may call this.
create or replace function public.generate_scanner_session(p_event_id uuid)
returns public.scanner_sessions
language plpgsql
security definer set search_path = public
as $$
declare
  v_organizer_id uuid := auth.uid();
  v_session public.scanner_sessions;
begin
  if v_organizer_id is null then
    raise exception 'You need to be signed in to start a scanner session.';
  end if;

  if not exists (
    select 1 from public.events
    where event_id = p_event_id
      and (organizer_id = v_organizer_id or public.is_admin())
  ) then
    raise exception 'You do not have access to this event.';
  end if;

  -- Revoke any previous still-active session for this event so there's
  -- only ever one live link/PIN pair per event at a time.
  update public.scanner_sessions
    set status = 'revoked', revoked_at = now()
    where event_id = p_event_id and status = 'active';

  insert into public.scanner_sessions (
    session_pin, event_id, organizer_id, session_token, status, expires_at
  )
  values (
    lpad((floor(random() * 10000))::text, 4, '0'),
    p_event_id,
    v_organizer_id,
    encode(gen_random_bytes(16), 'hex'),
    'active',
    now() + interval '12 hours'
  )
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.generate_scanner_session(uuid) to authenticated;

-- ── 2. Revoke/end a scanner session (organizer or admin only) ───────────
create or replace function public.revoke_scanner_session(p_session_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.scanner_sessions
    set status = 'revoked', revoked_at = now()
    where session_id = p_session_id
      and (organizer_id = auth.uid() or public.is_admin());

  if not found then
    raise exception 'Session not found or you do not have access to it.';
  end if;
end;
$$;

grant execute on function public.revoke_scanner_session(uuid) to authenticated;

-- ── 3. Validate a staff PIN + link/token (roadmap item 25) ───────────────
-- Callable by anyone holding the token+PIN — entry staff never sign in.
create or replace function public.validate_scanner_session(p_token text, p_pin text)
returns table (session_id uuid, event_id uuid, event_title text)
language plpgsql
security definer set search_path = public
as $$
begin
  return query
    select s.session_id, s.event_id, e.title
    from public.scanner_sessions s
    join public.events e on e.event_id = s.event_id
    where s.session_token = p_token
      and s.session_pin = p_pin
      and s.status = 'active'
      and s.expires_at > now();

  if not found then
    raise exception 'That link and PIN are invalid or have expired.';
  end if;
end;
$$;

grant execute on function public.validate_scanner_session(text, text) to anon, authenticated;

-- ── 4. Scan a ticket's QR at the door (roadmap items 26 & 27) ────────────
-- This is where QR *invalidation* actually happens: a ticket scanned
-- 'valid' is immediately flipped to ticket_status='used',
-- qr_status='used' — so the same QR code can never be accepted twice,
-- even if the buyer screenshots it and shares it with someone else.
create or replace function public.scan_ticket(
  p_token text,
  p_pin text,
  p_qr_code_token text
)
returns table (result text, event_title text, tier_name text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_session_id uuid;
  v_event_id uuid;
  v_event_title text;
  v_ticket public.tickets;
  v_tier_name text;
  v_ticket_event_id uuid;
  v_result text;
begin
  select s.session_id, s.event_id, e.title
    into v_session_id, v_event_id, v_event_title
    from public.scanner_sessions s
    join public.events e on e.event_id = s.event_id
    where s.session_token = p_token
      and s.session_pin = p_pin
      and s.status = 'active'
      and s.expires_at > now();

  if not found then
    raise exception 'That link and PIN are invalid or have expired.';
  end if;

  select t.*, tt.tier_name, tt.event_id
    into v_ticket, v_tier_name, v_ticket_event_id
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    where t.qr_code_token = p_qr_code_token;

  if not found then
    -- No matching ticket at all — nothing to log a scan against (
    -- qr_scan_logs.ticket_id is not-null), so just report the result.
    return query select 'invalid'::text, v_event_title, null::text;
    return;
  end if;

  if v_ticket_event_id <> v_event_id then
    v_result := 'wrong_event';
  elsif v_ticket.ticket_status = 'used' or v_ticket.qr_status = 'used' then
    v_result := 'already_used';
  else
    v_result := 'valid';
    update public.tickets
      set ticket_status = 'used', qr_status = 'used', used_at = now()
      where ticket_id = v_ticket.ticket_id;
  end if;

  insert into public.qr_scan_logs (ticket_id, session_id, scan_result, device_info)
  values (v_ticket.ticket_id, v_session_id, v_result::scan_result, 'mobile_scanner');

  return query select v_result, v_event_title, v_tier_name;
end;
$$;

grant execute on function public.scan_ticket(text, text, text) to anon, authenticated;

-- ── 5. Reissue a ticket's QR (roadmap item 27, resale half) ──────────────
-- Generates a fresh, unguessable qr_code_token and resets the ticket back
-- to a scannable state — the old QR code (e.g. a screenshot the previous
-- owner still has) stops being the "real" one the moment this runs, since
-- lookups are always by exact qr_code_token match. Intended to be called
-- the instant a resale purchase completes and ownership transfers; not
-- yet wired into resale_checkout_screen.dart, since the resale purchase
-- flow itself is still local-only (tracked separately from this pass).
create or replace function public.reissue_ticket_qr(p_ticket_id uuid)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  v_ticket public.tickets;
begin
  update public.tickets
    set qr_code_token = 'FTX-RS-' || encode(gen_random_bytes(12), 'hex'),
        qr_status = 'active',
        ticket_status = 'valid',
        used_at = null
    where ticket_id = p_ticket_id
      and (owner_id = auth.uid() or public.is_admin())
    returning * into v_ticket;

  if not found then
    raise exception 'Ticket not found or you do not have access to it.';
  end if;

  return v_ticket;
end;
$$;

grant execute on function public.reissue_ticket_qr(uuid) to authenticated;
