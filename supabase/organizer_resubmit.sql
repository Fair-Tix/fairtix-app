-- =============================================================================
-- FairTix - let a REJECTED organizer resubmit their application.
-- Run in the Supabase SQL Editor after schema.sql. Safe to re-run.
--
-- The organizer re-uploads the two verification documents from the app (the
-- same Storage upload used at registration), then calls this function. It only
-- moves the account from 'rejected' back to 'pending' so an admin reviews it
-- again, and only when both documents are on file. Organizers cannot set any
-- other status themselves; approval stays an admin-only action.
-- =============================================================================

create or replace function public.resubmit_organizer_application()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'You need to be signed in to resubmit your application.';
  end if;

  update public.users
     set id_verification_status = 'pending',
         updated_at = now()
   where id = v_uid
     and role = 'organizer'
     and id_verification_status = 'rejected'
     and venue_proof_url is not null
     and event_permit_url is not null;

  if not found then
    raise exception 'Only a rejected organizer application with both documents uploaded can be resubmitted.';
  end if;
end;
$$;

revoke all on function public.resubmit_organizer_application() from public, anon;
grant execute on function public.resubmit_organizer_application() to authenticated;
