-- =============================================================================
-- FairTix — per-user notification preferences.
-- Run in the Supabase SQL Editor AFTER schema.sql and policies.sql, and re-run
-- notification_functions.sql afterwards (its notify_user() reads this table).
-- Safe to re-run.
--
-- One row per user, created the first time the user saves Settings >
-- Notifications. A user with NO row gets every notification (all four flags
-- default to true), so nothing changes until someone opts out.
--
--   email_enabled  : false = no 'email' rows are written for the user.
--   push_enabled   : false = no 'push' rows are written for the user.
--   resale_enabled : false = no resale notification on ANY channel.
--   promo_enabled  : false = no promotional notification on ANY channel
--                    (organizer / admin announcements).
--
-- In-app delivery for ticket, system and account notifications is
-- transactional and has no switch. The filtering itself happens in
-- notify_user() (notification_functions.sql), the single function every
-- notification goes through, so the app, the PayMongo webhook and admin
-- actions are all covered. A user can only read and write their own row.
-- =============================================================================

create table if not exists public.notification_preferences (
  user_id        uuid primary key references public.users(id) on delete cascade,
  email_enabled  boolean not null default true,
  push_enabled   boolean not null default true,
  resale_enabled boolean not null default true,
  promo_enabled  boolean not null default true,
  updated_at     timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists "notif_prefs_select_own" on public.notification_preferences;
create policy "notif_prefs_select_own"
  on public.notification_preferences for select
  using (user_id = auth.uid());

drop policy if exists "notif_prefs_insert_own" on public.notification_preferences;
create policy "notif_prefs_insert_own"
  on public.notification_preferences for insert
  with check (user_id = auth.uid());

drop policy if exists "notif_prefs_update_own" on public.notification_preferences;
create policy "notif_prefs_update_own"
  on public.notification_preferences for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Keep updated_at honest on every save.
create or replace function public.touch_notification_preferences()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists touch_notification_preferences on public.notification_preferences;
create trigger touch_notification_preferences
  before update on public.notification_preferences
  for each row execute procedure public.touch_notification_preferences();

grant select, insert, update on public.notification_preferences to authenticated;
