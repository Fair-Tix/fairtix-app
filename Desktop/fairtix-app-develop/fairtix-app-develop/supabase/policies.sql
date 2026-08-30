-- =============================================================================
-- FairTix — Row-Level Security policies (replaces firestore.rules)
-- Run AFTER schema.sql. Mirrors the same role-based access model:
-- buyer / organizer / admin, scoped to each user's own rows unless admin.
-- =============================================================================

-- ── Helper functions ─────────────────────────────────────────────────────
-- SECURITY DEFINER + a fixed search_path so these are safe to call from
-- inside policies without risking privilege-escalation via search_path
-- hijacking, and so they bypass RLS on public.users themselves (otherwise
-- checking "am I admin" would recursively require a policy on users).

create function public.my_role()
returns user_role
language sql stable security definer set search_path = public
as $$
  select role from public.users where id = auth.uid();
$$;

create function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.my_role() = 'admin';
$$;

create function public.is_organizer()
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.my_role() = 'organizer';
$$;

-- ── Enable RLS on every table ────────────────────────────────────────────
alter table public.users                    enable row level security;
alter table public.organizer_subscriptions  enable row level security;
alter table public.events                   enable row level security;
alter table public.ticket_tiers             enable row level security;
alter table public.tickets                  enable row level security;
alter table public.transactions             enable row level security;
alter table public.resale_listings          enable row level security;
alter table public.scanner_sessions         enable row level security;
alter table public.qr_scan_logs             enable row level security;
alter table public.notifications            enable row level security;
alter table public.organizer_fees           enable row level security;

-- ── Users ─────────────────────────────────────────────────────────────────
-- Each user can read/update their own profile. Admins can read/update any
-- profile (approvals, suspend/ban). Nobody can change their own `role`
-- column — only an admin, via a SECURITY DEFINER RPC, may promote a user.
create policy "users_select_own_or_admin"
  on public.users for select
  using (id = auth.uid() or public.is_admin());

create policy "users_insert_own"
  on public.users for insert
  with check (id = auth.uid());

create policy "users_update_own_or_admin"
  on public.users for update
  using (id = auth.uid() or public.is_admin())
  with check (
    public.is_admin()
    or (id = auth.uid() and role = (select role from public.users where id = auth.uid()))
  );

create policy "users_delete_admin_only"
  on public.users for delete
  using (public.is_admin());

-- ── Organizer Subscriptions ─────────────────────────────────────────────
create policy "org_subs_select"
  on public.organizer_subscriptions for select
  using (public.is_admin() or (public.is_organizer() and user_id = auth.uid()));

-- An organizer may create/update their OWN subscription row (choosing or
-- changing a plan from organizer-subscription-plan.dart) — this is just
-- recording which plan they picked, not a payment operation, so it's safe
-- to allow client-side. Deletion stays admin-only. (Was previously
-- "org_subs_write_admin_only for all", which blocked organizers from ever
-- persisting a plan choice themselves.)
create policy "org_subs_insert_own"
  on public.organizer_subscriptions for insert
  with check (public.is_organizer() and user_id = auth.uid());

create policy "org_subs_update_own_or_admin"
  on public.organizer_subscriptions for update
  using (public.is_admin() or (public.is_organizer() and user_id = auth.uid()))
  with check (public.is_admin() or (public.is_organizer() and user_id = auth.uid()));

create policy "org_subs_delete_admin_only"
  on public.organizer_subscriptions for delete
  using (public.is_admin());

-- ── Events & Ticket Tiers ───────────────────────────────────────────────
-- Published events are readable by any signed-in user (buyers browsing the
-- catalogue). Only the owning organizer or an admin may write.
create policy "events_select_signed_in"
  on public.events for select
  using (auth.uid() is not null);

create policy "events_insert_own_organizer"
  on public.events for insert
  with check (public.is_organizer() and organizer_id = auth.uid());

create policy "events_update_own_or_admin"
  on public.events for update
  using (public.is_admin() or (public.is_organizer() and organizer_id = auth.uid()));

create policy "events_delete_own_or_admin"
  on public.events for delete
  using (public.is_admin() or (public.is_organizer() and organizer_id = auth.uid()));

create policy "ticket_tiers_select_signed_in"
  on public.ticket_tiers for select
  using (auth.uid() is not null);

create policy "ticket_tiers_write_owning_organizer_or_admin"
  on public.ticket_tiers for all
  using (
    public.is_admin()
    or exists (
      select 1 from public.events e
      where e.event_id = ticket_tiers.event_id and e.organizer_id = auth.uid()
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.events e
      where e.event_id = ticket_tiers.event_id and e.organizer_id = auth.uid()
    )
  );

-- ── Tickets ───────────────────────────────────────────────────────────────
-- Owners read their own tickets. Organizers read tickets for their own
-- events (entry validation / dashboards). Admins read/manage everything.
-- Updates (QR rotation, ownership transfer on resale) are Edge-Function
-- (service_role) only — no direct client update policy is granted, matching
-- the original "allow update: if isAdmin() || false" intent.
create policy "tickets_select_owner_organizer_or_admin"
  on public.tickets for select
  using (
    public.is_admin()
    or owner_id = auth.uid()
    or (public.is_organizer() and exists (
      select 1 from public.ticket_tiers tt
      join public.events e on e.event_id = tt.event_id
      where tt.tier_id = tickets.tier_id and e.organizer_id = auth.uid()
    ))
  );

create policy "tickets_insert_own_purchase"
  on public.tickets for insert
  with check (owner_id = auth.uid());

create policy "tickets_delete_admin_only"
  on public.tickets for delete
  using (public.is_admin());

-- No UPDATE policy is created for non-admins on purpose: QR signing and
-- resale ownership transfer must go through a SECURITY DEFINER Edge
-- Function so business rules (fixed-price ceiling, escrow, QR
-- invalidation) can't be bypassed by a direct client write.
create policy "tickets_update_admin_only"
  on public.tickets for update
  using (public.is_admin());

-- ── Transactions ──────────────────────────────────────────────────────────
create policy "transactions_select_participant_or_admin"
  on public.transactions for select
  using (public.is_admin() or buyer_id = auth.uid() or seller_id = auth.uid());

create policy "transactions_insert_own_as_buyer"
  on public.transactions for insert
  with check (buyer_id = auth.uid());

-- Escrow release / refunds: Edge Functions (service_role) only.
create policy "transactions_update_admin_only"
  on public.transactions for update
  using (public.is_admin());

-- ── Resale Listings ───────────────────────────────────────────────────────
create policy "resale_listings_select_signed_in"
  on public.resale_listings for select
  using (auth.uid() is not null);

create policy "resale_listings_insert_own"
  on public.resale_listings for insert
  with check (seller_id = auth.uid());

create policy "resale_listings_update_own_or_admin"
  on public.resale_listings for update
  using (public.is_admin() or seller_id = auth.uid());

create policy "resale_listings_delete_own_or_admin"
  on public.resale_listings for delete
  using (public.is_admin() or seller_id = auth.uid());

-- ── Scanner Sessions & QR Scan Logs ───────────────────────────────────────
create policy "scanner_sessions_all_owning_organizer_or_admin"
  on public.scanner_sessions for all
  using (public.is_admin() or (public.is_organizer() and organizer_id = auth.uid()))
  with check (public.is_admin() or (public.is_organizer() and organizer_id = auth.uid()));

create policy "qr_scan_logs_select_admin_or_organizer"
  on public.qr_scan_logs for select
  using (public.is_admin() or public.is_organizer());

create policy "qr_scan_logs_insert_signed_in"
  on public.qr_scan_logs for insert
  with check (auth.uid() is not null); -- written by the entry-staff scanner session

create policy "qr_scan_logs_update_admin_only"
  on public.qr_scan_logs for update
  using (public.is_admin());

create policy "qr_scan_logs_delete_admin_only"
  on public.qr_scan_logs for delete
  using (public.is_admin());

-- ── Notifications ─────────────────────────────────────────────────────────
create policy "notifications_select_own_or_admin"
  on public.notifications for select
  using (public.is_admin() or user_id = auth.uid());

create policy "notifications_update_own_or_admin"
  on public.notifications for update
  using (public.is_admin() or user_id = auth.uid());

-- Sent by Edge Functions / organizer announcement flow (service_role),
-- matching the original "allow create: if isAdmin()" intent.
create policy "notifications_insert_admin_only"
  on public.notifications for insert
  with check (public.is_admin());

-- ── Organizer Fees ────────────────────────────────────────────────────────
create policy "organizer_fees_select_own_or_admin"
  on public.organizer_fees for select
  using (public.is_admin() or (public.is_organizer() and organizer_id = auth.uid()));

-- Computed by Edge Functions (service_role) only.
create policy "organizer_fees_write_admin_only"
  on public.organizer_fees for all
  using (public.is_admin())
  with check (public.is_admin());


-- =============================================================================
-- Storage buckets & policies (replaces storage.rules)
-- Create the buckets first (Dashboard → Storage, or the block below), then
-- apply these policies to `storage.objects`.
-- =============================================================================

insert into storage.buckets (id, name, public)
values
  ('identity_docs', 'identity_docs', false),
  ('organizer_docs', 'organizer_docs', false),
  ('event_banners', 'event_banners', true)
on conflict (id) do nothing;

-- identity_docs/{userId}/{fileName}: private to the owner + admins.
-- Supabase Storage policies match on storage.foldername(name), where
-- foldername(name)[1] is the first path segment (mirrors {userId}/...).
create policy "identity_docs_select_owner_or_admin"
  on storage.objects for select
  using (
    bucket_id = 'identity_docs'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy "identity_docs_insert_owner"
  on storage.objects for insert
  with check (
    bucket_id = 'identity_docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- organizer_docs/{organizerId}/{fileName}: private to the submitting
-- organizer + admins.
create policy "organizer_docs_select_owner_or_admin"
  on storage.objects for select
  using (
    bucket_id = 'organizer_docs'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy "organizer_docs_insert_owner"
  on storage.objects for insert
  with check (
    bucket_id = 'organizer_docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- event_banners/{eventId}/{fileName}: public read; writable by any signed-in
-- user for now (mirrors the original rule's own NOTE that it should be
-- tightened to "only the organizer who owns {eventId}" once that check is
-- feasible — doable here since Postgres CAN join back to events.organizer_id,
-- unlike the original Firestore rule which could not).
create policy "event_banners_public_read"
  on storage.objects for select
  using (bucket_id = 'event_banners');

create policy "event_banners_insert_owning_organizer_or_admin"
  on storage.objects for insert
  with check (
    bucket_id = 'event_banners'
    and (
      public.is_admin()
      or exists (
        select 1 from public.events e
        where e.event_id::text = (storage.foldername(name))[1]
          and e.organizer_id = auth.uid()
      )
    )
  );
