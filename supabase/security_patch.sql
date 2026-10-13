-- =============================================================================
-- FairTix — security patch (found while auditing items 1-13)
-- Run in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run (drop if exists / create).
--
-- 1. Tickets and transactions can no longer be inserted straight from the app.
--    policies.sql still has "tickets_insert_own_purchase" and
--    "transactions_insert_own_as_buyer", which let any signed-in user insert
--    a ticket for themselves through the API and skip payment entirely
--    (the paymongo-verify / webhook path is only the *honest* client's path).
--    Every legitimate insert goes through _do_ticket_purchase, a SECURITY
--    DEFINER function owned by the table owner, which is not affected by RLS,
--    so dropping these policies does not break purchases.
--
-- 2. Organizers can save their subscription plan.
--    organizer_subscription_service.dart inserts/updates the organizer's own
--    organizer_subscriptions row, but policies.sql only allows admin writes
--    ("org_subs_write_admin_only"), so choosing a plan fails with an RLS
--    error and every organizer falls back to the 10% default fee. The fee
--    per plan (8% / 9% / 10%) cannot work until this exists.
--    NOTE: this only lets an organizer write THEIR OWN row; there is still
--    no payment step for the subscription (sandbox scope).
--
-- 3. reissue_ticket_qr is no longer callable by ticket owners.
--    It resets a ticket to valid/active with used_at = null. Granted to
--    `authenticated` and only checking ownership, any owner could call it on
--    a ticket that was already scanned (or canceled) and get a fresh working
--    QR code, which defeats "QR invalidated on use". Nothing in the app calls
--    it yet; the future resale-purchase function should call it from inside
--    its own SECURITY DEFINER body (which does not need this grant).
--
-- 4. Nobody can approve or un-suspend themselves.
--    The users update policy in policies.sql only checks that `role` is
--    unchanged, so any signed-in eventgoer or organizer could send
--    {"id_verification_status": "verified"} for their own row straight to the
--    API and skip the admin review completely (or flip their own
--    account_status back to active). The trigger below blocks that. Admins
--    and the SQL Editor / service role (no signed-in user) are unaffected.
--    The one change a person may still make is rejected -> pending, which is
--    exactly what re-uploading an ID after a rejection does.
-- =============================================================================

-- 1. No direct client inserts of tickets / transactions ---------------------
drop policy if exists "tickets_insert_own_purchase" on public.tickets;
drop policy if exists "transactions_insert_own_as_buyer" on public.transactions;

-- 2. Organizers manage their own subscription row ---------------------------
drop policy if exists "org_subs_insert_own" on public.organizer_subscriptions;
create policy "org_subs_insert_own"
  on public.organizer_subscriptions for insert
  with check (public.is_organizer() and user_id = auth.uid());

drop policy if exists "org_subs_update_own_or_admin" on public.organizer_subscriptions;
create policy "org_subs_update_own_or_admin"
  on public.organizer_subscriptions for update
  using (public.is_admin() or (public.is_organizer() and user_id = auth.uid()))
  with check (public.is_admin() or (public.is_organizer() and user_id = auth.uid()));

-- 3. Ticket owners cannot reissue their own QR ------------------------------
revoke execute on function public.reissue_ticket_qr(uuid) from public, anon, authenticated;

-- 4. Protect verification / status / identity columns on public.users -------
create or replace function public.protect_user_columns()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- No signed-in user (SQL Editor, service role) or an admin: allowed.
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'You cannot change your own role.';
  end if;

  if new.account_status is distinct from old.account_status then
    raise exception 'You cannot change your own account status.';
  end if;

  if new.id_number is distinct from old.id_number
     or new.face_embedding_hash is distinct from old.face_embedding_hash then
    raise exception 'Identity fields can only be changed by an administrator.';
  end if;

  if new.id_verification_status is distinct from old.id_verification_status then
    -- Only allowed move: resubmitting documents after a rejection.
    if not (old.id_verification_status = 'rejected' and new.id_verification_status = 'pending') then
      raise exception 'Verification status can only be changed by an administrator.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.protect_user_columns() from public, anon, authenticated;

drop trigger if exists protect_user_columns on public.users;
create trigger protect_user_columns
  before update on public.users
  for each row execute procedure public.protect_user_columns();
