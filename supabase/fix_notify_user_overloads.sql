-- =============================================================================
-- FairTix — fix: "function public.notify_user(uuid, unknown, text, unknown) is
-- not unique" (seen when an organizer cancels an event).
--
-- Cause: the database holds MORE THAN ONE notify_user() function, left over
-- from an older version of notification_functions.sql (which only drops one
-- specific old signature). The trigger calls notify_user(uuid, 'text',
-- 'text', 'system'); with two candidates Postgres cannot choose.
--
-- Fix: keep only the current 6-argument version defined in
-- notification_functions.sql and drop every other notify_user overload.
-- Run in the Supabase SQL Editor. Safe to re-run.
--
-- To just LOOK at what exists first, run this on its own:
--   select p.oid::regprocedure
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public' and p.proname = 'notify_user';
-- =============================================================================

-- The current version must exist (it is created by notification_functions.sql).
-- If this statement errors with "function ... does not exist", run
-- notification_functions.sql first, then run this file again.
do $$
declare
  r record;
  v_keep oid := 'public.notify_user(uuid,text,text,notification_type,boolean,boolean)'::regprocedure;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'notify_user'
      and p.oid <> v_keep
  loop
    execute 'drop function ' || r.sig;
    raise notice 'Dropped extra overload: %', r.sig;
  end loop;
end
$$;
