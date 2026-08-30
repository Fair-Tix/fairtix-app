-- =============================================================================
-- FairTix — Supabase (Postgres) schema
-- Mirrors the Data Dictionary in PROJECT_FAIRTIX.pdf (Chapter III, Tables 6-16)
-- Run this in the Supabase SQL Editor (or via `supabase db push`) BEFORE
-- policies.sql, since the policies attach to these tables.
-- =============================================================================

-- ── Extensions ────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ── Enums ─────────────────────────────────────────────────────────────────
create type user_role as enum ('buyer', 'organizer', 'admin');
create type id_verification_status as enum ('pending', 'verified', 'rejected');
create type account_status as enum ('active', 'suspended', 'deactivated');
create type subscription_status as enum ('active', 'expired', 'canceled');
create type event_type as enum ('single_day', 'multi_day');
create type event_status as enum ('draft', 'published', 'canceled', 'completed');
create type qr_status as enum ('active', 'used', 'invalidated');
create type ticket_status as enum ('valid', 'used', 'listed', 'canceled');
create type transaction_type as enum ('purchase', 'resale');
create type transaction_status as enum ('pending', 'completed', 'failed', 'refunded');
create type escrow_status as enum ('held', 'released', 'refunded');
create type listing_status as enum ('active', 'sold', 'canceled', 'expired');
create type scanner_session_status as enum ('active', 'expired', 'revoked');
create type scan_result as enum ('valid', 'already_used', 'invalid', 'wrong_event');
create type notification_type as enum ('ticket', 'resale', 'system', 'promo');
create type notification_channel as enum ('in_app', 'email', 'push');
create type fee_status as enum ('pending', 'paid', 'withheld');

-- ── Users (Table 6) ──────────────────────────────────────────────────────
-- Note: `id` IS the Supabase Auth user id (auth.users.id), 1:1. This is the
-- standard Supabase pattern — no separate FK/uuid needed. A trigger below
-- auto-creates a row here whenever someone signs up via Supabase Auth.
create table public.users (
  id                    uuid primary key references auth.users(id) on delete cascade,
  full_name             text not null,
  username              text unique,
  organization_name     text,
  email                 text not null unique,
  phone                 text,
  birth_date            date,
  id_document_url       text,
  id_type               text,
  id_verification_status id_verification_status not null default 'pending',
  id_number             text unique,
  selfie_photo_url      text,
  face_embedding_hash   text,
  -- Not part of the original Data Dictionary (Table 6) — added because
  -- organizer-register.dart's UI collects two separate proof-of-
  -- organization documents ("Proof of Venue Booking" and "Valid Event
  -- Permit") rather than the single generic id_document_url the schema
  -- originally modeled. Both live in the same private `organizer_docs`
  -- Storage bucket as the organizer's other verification files.
  venue_proof_url       text,
  event_permit_url      text,
  role                  user_role not null default 'buyer',
  profile_photo_url     text,
  account_status        account_status not null default 'active',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Auto-create a public.users row on signup (role defaults to 'buyer';
-- promote to organizer/admin via an admin-only RPC, never client-side).
-- full_name/username/phone/birth_date/organization_name come from the
-- `data` map passed to supabase.auth.signUp() on the client (see
-- registration_screen.dart / organizer-register.dart and
-- user_auth_service.dart / organizer_auth_service.dart) — Supabase stores
-- that as auth.users.raw_user_meta_data.
--
-- `role` is also read from that same metadata, but deliberately
-- constrained here (server-side, inside a SECURITY DEFINER trigger) to
-- only ever become 'buyer' or 'organizer' — never 'admin' — no matter
-- what a client sends. This lets the "Register as Organizer" flow work
-- without an Edge Function, while preserving the guarantee in
-- policies.sql that nobody can self-promote to admin.
--
-- NOTE: setting role = 'organizer' here only marks account *type*, not
-- approval. `id_verification_status` stays 'pending' until an admin
-- reviews the submitted documents (see organizer-verification-pending.dart
-- / Phase 6). Policies that gate organizer *actions* (creating events,
-- etc.) currently only check role via is_organizer() and do not yet check
-- id_verification_status — tightening that is tracked as a Phase 2/6 TODO,
-- not done in this pass.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  requested_role text := nullif(new.raw_user_meta_data->>'role', '');
  safe_full_name text := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), split_part(new.email, '@', 1));
  safe_organization_name text := nullif(new.raw_user_meta_data->>'organization_name', '');
  safe_phone text := nullif(new.raw_user_meta_data->>'phone', '');
  safe_birth_date date := nullif(new.raw_user_meta_data->>'birth_date', '')::date;
begin
  insert into public.users (
    id,
    full_name,
    username,
    organization_name,
    email,
    phone,
    birth_date,
    role
  )
  values (
    new.id,
    safe_full_name,
    nullif(new.raw_user_meta_data->>'username', ''),
    safe_organization_name,
    new.email,
    safe_phone,
    safe_birth_date,
    case when requested_role = 'organizer' then 'organizer'::user_role else 'buyer'::user_role end
  )
  on conflict (id) do update
  set
    full_name = excluded.full_name,
    username = excluded.username,
    organization_name = excluded.organization_name,
    email = excluded.email,
    phone = excluded.phone,
    birth_date = excluded.birth_date,
    role = excluded.role,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

-- ── Organizer Subscriptions (Table 7) ───────────────────────────────────
create table public.organizer_subscriptions (
  subscription_id uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  start_date      date not null,
  end_date        date not null,
  status          subscription_status not null default 'active',
  monthly_fee     numeric(10,2) not null,
  created_at      timestamptz not null default now()
);

-- ── Events (Table 8) ─────────────────────────────────────────────────────
create table public.events (
  event_id         uuid primary key default gen_random_uuid(),
  event_type       event_type not null,
  parent_event_id  uuid references public.events(event_id) on delete cascade,
  day_number       int,
  event_start_date date not null,
  event_end_date   date,
  organizer_id     uuid not null references public.users(id),
  title            text not null,
  description      text,
  venue            text not null,
  banner_image_url text,
  status           event_status not null default 'draft',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create or replace function public.generate_multiday_sub_events()
returns trigger
language plpgsql
as $$
declare
  current_day date;
  day_index integer := 1;
begin
  if NEW.event_type <> 'multi_day' then
    return NEW;
  end if;

  if NEW.parent_event_id is not null then
    return NEW;
  end if;

  if NEW.event_end_date is null then
    raise exception 'Multi-day events must have an end date.';
  end if;

  for current_day in
    select generate_series(NEW.event_start_date, NEW.event_end_date, interval '1 day')::date
  loop
    insert into public.events (
      event_type,
      parent_event_id,
      day_number,
      organizer_id,
      title,
      description,
      venue,
      banner_image_url,
      status,
      event_start_date,
      event_end_date
    )
    values (
      'multi_day',
      NEW.event_id,
      day_index,
      NEW.organizer_id,
      NEW.title || ' — Day ' || day_index,
      NEW.description,
      NEW.venue,
      NEW.banner_image_url,
      NEW.status,
      current_day,
      null
    );

    day_index := day_index + 1;
  end loop;

  return NEW;
end;
$$;

drop trigger if exists trg_generate_multiday_sub_events on public.events;
create trigger trg_generate_multiday_sub_events
after insert on public.events
for each row
execute function public.generate_multiday_sub_events();

-- ── Ticket Tiers (Table 9) ───────────────────────────────────────────────
create table public.ticket_tiers (
  tier_id            uuid primary key default gen_random_uuid(),
  event_id           uuid not null references public.events(event_id) on delete cascade,
  tier_name          text not null,
  base_price         numeric(10,2) not null,
  total_quantity     int not null,
  remaining_quantity int not null,
  created_at         timestamptz not null default now()
);

-- ── Tickets (Table 10) ───────────────────────────────────────────────────
create table public.tickets (
  ticket_id      uuid primary key default gen_random_uuid(),
  tier_id        uuid not null references public.ticket_tiers(tier_id),
  owner_id       uuid not null references public.users(id),
  qr_code_token  text not null unique,
  qr_status      qr_status not null default 'active',
  ticket_status  ticket_status not null default 'valid',
  purchase_price numeric(10,2) not null,
  service_fee    numeric(10,2) not null,
  purchased_at   timestamptz,
  used_at        timestamptz
);

-- ── Transactions (Table 11) ──────────────────────────────────────────────
create table public.transactions (
  transaction_id   uuid primary key default gen_random_uuid(),
  ticket_id        uuid not null references public.tickets(ticket_id),
  buyer_id         uuid not null references public.users(id),
  seller_id        uuid references public.users(id),
  transaction_type transaction_type not null,
  amount           numeric(10,2) not null,
  platform_fee     numeric(10,2) not null,
  status           transaction_status not null default 'pending',
  escrow_status    escrow_status not null default 'held',
  escrow_amount    numeric(10,2) not null,
  created_at       timestamptz not null default now()
);

-- ── Resale Listings (Table 12) ───────────────────────────────────────────
create table public.resale_listings (
  listing_id     uuid primary key default gen_random_uuid(),
  ticket_id      uuid not null references public.tickets(ticket_id),
  seller_id      uuid not null references public.users(id),
  listing_price  numeric(10,2) not null,
  listing_status listing_status not null default 'active',
  listed_at      timestamptz not null default now(),
  sold_at        timestamptz,
  escrow_status  escrow_status not null default 'held',
  constraint listing_price_within_band check (
    listing_price >= 0 -- app/edge-function layer enforces the 50%-100% band
    -- against ticket_tiers.base_price at insert time (needs a join Postgres
    -- CHECK constraints can't express directly); see Edge Function notes
    -- in the roadmap doc.
  )
);

-- ── Scanner Sessions (Table 13) ──────────────────────────────────────────
create table public.scanner_sessions (
  session_id     uuid primary key default gen_random_uuid(),
  session_pin    text not null,
  event_id       uuid not null references public.events(event_id) on delete cascade,
  organizer_id   uuid not null references public.users(id),
  session_token  text not null unique,
  status         scanner_session_status not null default 'active',
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null,
  revoked_at     timestamptz
);

-- ── QR Scan Logs (Table 14) ──────────────────────────────────────────────
create table public.qr_scan_logs (
  log_id      uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references public.tickets(ticket_id),
  session_id  uuid not null references public.scanner_sessions(session_id),
  scan_result scan_result not null,
  device_info text,
  scanned_at  timestamptz not null default now()
);

-- ── Notifications (Table 15) ─────────────────────────────────────────────
create table public.notifications (
  notification_id uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  title           text not null,
  message         text not null,
  type            notification_type not null,
  channel         notification_channel not null,
  is_read         boolean not null default false,
  sent_at         timestamptz not null default now()
);

-- ── Organizer Fees (Table 16) ────────────────────────────────────────────
create table public.organizer_fees (
  fee_id         uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(transaction_id),
  organizer_id   uuid not null references public.users(id),
  gross_amount   numeric(10,2) not null,
  fee_rate       numeric(5,4) not null,
  fee_amount     numeric(10,2) not null,
  net_amount     numeric(10,2) not null,
  status         fee_status not null default 'pending',
  computed_at    timestamptz not null default now()
);

-- ── Indexes for common lookups ───────────────────────────────────────────
create index on public.events (organizer_id);
create index on public.ticket_tiers (event_id);
create index on public.tickets (owner_id);
create index on public.tickets (tier_id);
create index on public.transactions (buyer_id);
create index on public.transactions (seller_id);
create index on public.resale_listings (seller_id);
create index on public.resale_listings (listing_status);
create index on public.scanner_sessions (organizer_id);
create index on public.notifications (user_id);
