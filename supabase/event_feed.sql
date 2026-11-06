-- =============================================================================
-- FairTix — organizer info for the Home feed (post-style event cards).
-- Apply any time after schema.sql / policies.sql. Safe to re-run.
--
-- Eventgoers can't read other users' rows (users_select_own_or_admin), so the
-- feed asks this SECURITY DEFINER function for just two public facts about
-- each published event's organizer: a display name and whether the organizer
-- is approved. Nothing else from public.users is exposed (no email, phone,
-- ID or document URLs).
-- =============================================================================

create or replace function public.event_feed_organizers(p_event_ids uuid[])
returns table (
  event_id uuid,
  organizer_name text,
  is_verified boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.event_id,
    coalesce(
      nullif(btrim(u.organization_name), ''),
      nullif(btrim(u.full_name), ''),
      'Organizer'
    ) as organizer_name,
    (u.id_verification_status = 'verified' and u.account_status = 'active') as is_verified
  from public.events e
  join public.users u on u.id = e.organizer_id
  where auth.uid() is not null
    and e.status = 'published'
    and e.event_id = any(p_event_ids);
$$;

revoke all on function public.event_feed_organizers(uuid[]) from public, anon;
grant execute on function public.event_feed_organizers(uuid[]) to authenticated;
