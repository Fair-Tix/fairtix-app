-- =============================================================================
-- FairTix — Scanner session, live QR entry-validation, and QR
-- invalidation/reissuance RPCs.
-- Run this in the Supabase SQL Editor AFTER schema.sql and policies.sql.
-- Safe to re-run: everything below is `create or replace` / `if not exists`.
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
--
-- CHANGES in this revision (fixes for the 2026-10-09 system test):
--   * Token generation no longer uses gen_random_bytes(). On Supabase the
--     pgcrypto extension lives in the `extensions` schema, which is NOT on
--     these functions' `search_path = public`, so the old call failed with
--     "function gen_random_bytes(integer) does not exist" and no session
--     could ever be generated. gen_random_uuid() is built into Postgres,
--     so it works from `public` with no extension lookup.
--   * scan_ticket no longer does `select t.*, ... into <row var>, <scalar>`,
--     which PL/pgSQL cannot map (a row variable in a multi-target INTO
--     consumes only ONE column), so every real scan raised an error.
--   * Scanner link now expires when the event ends (end of its last day,
--     Asia/Manila), capped at 12 hours.
--   * Every scan is logged — including unknown/invalid QR codes
--     (qr_scan_logs.ticket_id is now nullable; the scanned token is kept).
--   * An accepted scan releases the held escrow on the ticket's primary
--     purchase transaction.
--   * Invalidated / canceled tickets are rejected as invalid.
--   * Tickets for a day of a multi-day event are accepted by the parent
--     event's session, but only on that day.
--   * New get_scan_activity() so the organizer can see the live scan feed.
-- =============================================================================

-- ── 0. Schema tweaks the scan log needs ──────────────────────────────────
-- An unknown QR code has no ticket to point at, so the FK column must be
-- nullable for "every scan is logged" to hold. The raw scanned token is
-- kept so the organizer can still see what was presented.
alter table public.qr_scan_logs alter column ticket_id drop not null;
alter table public.qr_scan_logs add column if not exists scanned_token text;

-- ── 1. Generate a scanner session (organizer only) ──────────────────────
-- Roadmap item 24. Creates a fresh session_token + 4-digit session_pin for
-- one event. Valid until the event ends (end of its last day, Asia/Manila)
-- or 12 hours, whichever comes first. Only the organizer who owns
-- [p_event_id] (or an admin) may call this.
create or replace function public.generate_scanner_session(p_event_id uuid)
returns public.scanner_sessions
language plpgsql
security definer set search_path = public
as $$
declare
  v_organizer_id uuid := auth.uid();
  v_event public.events;
  v_event_end timestamptz;
  v_session public.scanner_sessions;
begin
  if v_organizer_id is null then
    raise exception 'You need to be signed in to start a scanner session.';
  end if;

  select e.* into v_event
    from public.events e
    where e.event_id = p_event_id
      and (e.organizer_id = v_organizer_id or public.is_admin());

  if not found then
    raise exception 'You do not have access to this event.';
  end if;

  if v_event.status in ('draft', 'canceled') then
    raise exception 'Only published events can have a scanner session.';
  end if;

  -- Midnight at the END of the event's last day, Manila time.
  v_event_end := ((coalesce(v_event.event_end_date, v_event.event_start_date) + 1)::timestamp)
                 at time zone 'Asia/Manila';

  if v_event_end <= now() then
    raise exception 'This event has already ended.';
  end if;

  -- Tidy up: anything past its expiry becomes 'expired', and any other
  -- still-active session for this event is revoked so there is only ever
  -- one live link/PIN pair per event.
  update public.scanner_sessions
    set status = 'expired'
    where event_id = p_event_id and status = 'active' and expires_at <= now();

  update public.scanner_sessions
    set status = 'revoked', revoked_at = now()
    where event_id = p_event_id and status = 'active';

  insert into public.scanner_sessions (
    session_pin, event_id, organizer_id, session_token, status, expires_at
  )
  values (
    lpad((floor(random() * 10000))::int::text, 4, '0'),
    p_event_id,
    v_organizer_id,
    replace(gen_random_uuid()::text, '-', ''),
    'active',
    least(now() + interval '12 hours', v_event_end)
  )
  returning * into v_session;

  return v_session;
end;
$$;

grant execute on function public.generate_scanner_session(uuid) to authenticated;

-- ── 2. Revoke/end a scanner session (organizer or admin only) ───────────
-- Takes effect immediately: validate_scanner_session and scan_ticket both
-- require status = 'active' on every call.
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
-- A wrong PIN, a revoked session, and an expired session all give the same
-- generic error on purpose, so a guesser learns nothing.
create or replace function public.validate_scanner_session(p_token text, p_pin text)
returns table (session_id uuid, event_id uuid, event_title text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_session_id uuid;
  v_event_id uuid;
  v_title text;
begin
  select s.session_id, s.event_id, e.title
    into v_session_id, v_event_id, v_title
    from public.scanner_sessions s
    join public.events e on e.event_id = s.event_id
    where s.session_token = btrim(p_token)
      and s.session_pin = btrim(p_pin)
      and s.status = 'active'
      and s.expires_at > now();

  if not found then
    raise exception 'That link and PIN are invalid or have expired.';
  end if;

  return query select v_session_id, v_event_id, v_title;
end;
$$;

grant execute on function public.validate_scanner_session(text, text) to anon, authenticated;

-- ── 4. Scan a ticket's QR at the door (roadmap items 26 & 27) ────────────
-- This is where QR *invalidation* actually happens: a ticket scanned
-- 'valid' is immediately flipped to ticket_status='used',
-- qr_status='used' — so the same QR code can never be accepted twice,
-- even if the buyer screenshots it and shares it with someone else.
--
-- Results: valid | already_used | wrong_event | invalid. Every call —
-- including 'invalid' for an unknown QR — writes a qr_scan_logs row.
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
  v_session public.scanner_sessions;
  v_session_event public.events;
  v_ticket public.tickets;
  v_ticket_event public.events;
  v_ticket_id uuid := null;
  v_tier_name text := null;
  v_qr text := btrim(coalesce(p_qr_code_token, ''));
  v_result text;
  v_today date := (now() at time zone 'Asia/Manila')::date;
begin
  select s.* into v_session
    from public.scanner_sessions s
    where s.session_token = btrim(p_token)
      and s.session_pin = btrim(p_pin)
      and s.status = 'active'
      and s.expires_at > now();

  if not found then
    raise exception 'That link and PIN are invalid or have expired.';
  end if;

  select e.* into v_session_event
    from public.events e
    where e.event_id = v_session.event_id;

  -- Lock the ticket row so two staff phones scanning the same QR at the
  -- same instant can't both be told "accepted".
  select t.* into v_ticket
    from public.tickets t
    where t.qr_code_token = v_qr
    for update;

  if not found then
    v_result := 'invalid';
  else
    v_ticket_id := v_ticket.ticket_id;

    select tt.tier_name into v_tier_name
      from public.ticket_tiers tt
      where tt.tier_id = v_ticket.tier_id;

    select e.* into v_ticket_event
      from public.events e
      join public.ticket_tiers tt on tt.event_id = e.event_id
      where tt.tier_id = v_ticket.tier_id;

    if v_ticket_event.event_id is distinct from v_session_event.event_id
       and not (
         -- A ticket for one day of a multi-day run is good at the parent
         -- event's session, but only on that day.
         v_ticket_event.parent_event_id = v_session_event.event_id
         and v_ticket_event.event_start_date = v_today
       ) then
      v_result := 'wrong_event';
    elsif v_ticket.qr_status = 'invalidated' or v_ticket.ticket_status = 'canceled' then
      v_result := 'invalid';
    elsif v_ticket.ticket_status = 'used' or v_ticket.qr_status = 'used' then
      v_result := 'already_used';
    else
      v_result := 'valid';

      update public.tickets
        set ticket_status = 'used', qr_status = 'used', used_at = now()
        where ticket_id = v_ticket.ticket_id;

      -- Entry confirmed: release the escrow held on the primary purchase.
      update public.transactions
        set escrow_status = 'released'
        where ticket_id = v_ticket.ticket_id
          and transaction_type = 'purchase'
          and status = 'completed'
          and escrow_status = 'held';
    end if;
  end if;

  insert into public.qr_scan_logs (ticket_id, session_id, scan_result, device_info, scanned_token)
  values (v_ticket_id, v_session.session_id, v_result::scan_result, 'mobile_scanner', left(v_qr, 200));

  return query select v_result, v_session_event.title, v_tier_name;
end;
$$;

grant execute on function public.scan_ticket(text, text, text) to anon, authenticated;

-- ── 5. Live scan feed for the organizer ──────────────────────────────────
-- Latest scans for one session, newest first. Organizer who owns the
-- session (or an admin) only; anyone else just gets zero rows.
create or replace function public.get_scan_activity(p_session_id uuid, p_limit int default 50)
returns table (log_id uuid, scanned_at timestamptz, result text, tier_name text)
language sql
stable
security definer set search_path = public
as $$
  select l.log_id, l.scanned_at, l.scan_result::text, tt.tier_name
  from public.qr_scan_logs l
  join public.scanner_sessions s on s.session_id = l.session_id
  left join public.tickets t on t.ticket_id = l.ticket_id
  left join public.ticket_tiers tt on tt.tier_id = t.tier_id
  where l.session_id = p_session_id
    and (s.organizer_id = auth.uid() or public.is_admin())
  order by l.scanned_at desc
  limit greatest(least(p_limit, 200), 1);
$$;

grant execute on function public.get_scan_activity(uuid, int) to authenticated;

-- ── 6. Reissue a ticket's QR (roadmap item 27, resale half) ──────────────
-- Generates a fresh, unguessable qr_code_token and resets the ticket back
-- to a scannable state — the old QR code (e.g. a screenshot the previous
-- owner still has) stops being the "real" one the moment this runs, since
-- lookups are always by exact qr_code_token match. Intended to be called
-- the instant a resale purchase completes and ownership transfers; not
-- yet wired into resale_checkout_screen.dart, since the resale purchase
-- flow itself is still local-only (tracked separately from this pass).
--
-- (Uses gen_random_uuid() instead of gen_random_bytes() for the same
-- search_path reason as generate_scanner_session above.)
create or replace function public.reissue_ticket_qr(p_ticket_id uuid)
returns public.tickets
language plpgsql
security definer set search_path = public
as $$
declare
  v_ticket public.tickets;
begin
  update public.tickets
    set qr_code_token = 'FTX-RS-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 24),
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
