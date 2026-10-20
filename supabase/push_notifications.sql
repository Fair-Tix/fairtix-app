-- =============================================================================
-- FairTix — push notifications over Supabase Realtime (no Firebase)
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- notification_functions.sql. Safe to re-run.
--
-- How push works without Firebase/APNs:
--   * notify_user() (notification_functions.sql) writes a row with channel
--     'push' for events that should alert the phone, e.g. account / organizer
--     approval.
--   * The app subscribes to INSERTs on public.notifications for the signed-in
--     user over Supabase Realtime and shows a system notification for each
--     'push' row (lib/services/push_service.dart). Realtime honours the
--     table's row-level security, so a user only ever receives their own rows.
--   * On login / app start the app also shows any 'push' rows it missed while
--     it was closed, then marks them read so they never show twice.
--
-- This needs the table to be part of the Realtime publication, which is all
-- this file does. (Same effect as Dashboard -> Database -> Replication ->
-- supabase_realtime -> enable `notifications`.)
-- =============================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;
