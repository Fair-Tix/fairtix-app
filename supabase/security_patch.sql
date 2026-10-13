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
