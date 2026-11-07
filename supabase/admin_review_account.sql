-- =============================================================================
-- FairTix - admin_review_account (approve / reject an application)
-- Run in the Supabase SQL Editor AFTER audit_log.sql (re-run that file first:
-- its users trigger now reads the reason). Safe to re-run.
--
-- This function already existed in the Supabase database but was not in any
-- project SQL file. This is its definition as read from the database on
-- 2026-11-07, with ONE addition: the review reason (p_reason) is handed to the
-- audit trigger through the transaction-local setting fairtix.review_reason,
-- so that account_reviews.reason and admin_audit_log.details record why an
-- application was rejected. Nothing else changed: same signature, same checks,
-- same update. CREATE OR REPLACE keeps the existing grants.
--
-- Not covered: the reason is not shown to the applicant (the notification text
-- is unchanged) and it is only stored for rejections made after this is run.
-- =============================================================================

create or replace function public.admin_review_account(
  p_user_id uuid,
  p_status  id_verification_status,
  p_reason  text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can review accounts.';
  end if;
  if p_status not in ('verified', 'rejected') then
    raise exception 'Review status must be verified or rejected.';
  end if;

  -- true = local to this transaction, so it cannot leak into a later request.
  perform set_config('fairtix.review_reason', coalesce(btrim(p_reason), ''), true);

  update public.users
  set id_verification_status = p_status,
      updated_at = now()
  where id = p_user_id;
  if not found then
    raise exception 'The account could not be found.';
  end if;
end;
$$;
