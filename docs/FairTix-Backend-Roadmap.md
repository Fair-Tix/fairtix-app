# FairTix — Backend Integration Roadmap (Supabase)

> Supersedes the earlier Firebase-based roadmap. FairTix moved off Firebase
> because Cloud Storage requires the paid Blaze plan (credit card required).
> Supabase's free tier (Postgres + Auth + Storage + Edge Functions) needs no
> card and covers the same needs. This doc tracks what's done and what's next.

## Status as of this session

- ✅ `pubspec.yaml`: Firebase packages removed, `supabase_flutter` added
- ✅ `lib/main.dart`: `Firebase.initializeApp()` → `Supabase.initialize()`
- ✅ `lib/supabase_config.dart`: created with your project URL + anon key
- ✅ `android/settings.gradle.kts`, `android/app/build.gradle.kts`: Google
  Services plugin removed
- ✅ Firebase-only files moved to `_deprecated_firebase/` (safe to delete
  once the app builds clean): `firebase_options.dart`,
  `google-services.json`, `firebase.json`, `.firebaserc`,
  `firestore.rules`, `storage.rules`, `functions/`
- ✅ `supabase/schema.sql`: Postgres tables for all 11 entities in the
  Chapter III Data Dictionary (Users, Organizer Subscriptions, Events,
  Ticket Tiers, Tickets, Transactions, Resale Listings, Scanner Sessions,
  QR Scan Logs, Notifications, Organizer Fees)
- ✅ `supabase/policies.sql`: Row-Level Security policies (replaces
  `firestore.rules`) + Storage bucket policies (replaces `storage.rules`)
- ⬜ Nothing has been run against your actual Supabase project yet — the
  SQL files exist locally but the tables/policies aren't created remotely
  until you run them (see **Next action** below)

## Firebase → Supabase equivalents, for reference

| Firebase                        | Supabase equivalent                              |
|----------------------------------|---------------------------------------------------|
| Firebase Authentication          | Supabase Auth (`supabase.auth`)                   |
| Cloud Firestore (NoSQL)          | Postgres tables (`supabase.from('table')`)        |
| Firestore Security Rules         | Postgres Row-Level Security (RLS) policies        |
| Cloud Storage                    | Supabase Storage (buckets + storage policies)     |
| Cloud Functions                  | Supabase Edge Functions (Deno/TypeScript)          |
| Firebase Cloud Messaging (FCM)   | No built-in push; use a `notifications` table for in-app/email and pair with a third-party push provider later if needed |

## Immediate next action (before any Dart code changes take effect)

1. Open your Supabase project → **SQL Editor**.
2. Run `supabase/schema.sql` first (creates all tables + enums + the
   auto-profile trigger).
3. Run `supabase/policies.sql` second (enables RLS + creates all policies
   + the three Storage buckets).
4. Run `flutter pub get` locally to pull in `supabase_flutter`.
5. Confirm `flutter run -d chrome` (or your emulator) still builds with no
   Firebase references left.

## Phase 1 — Real Login/Register for all three portals (Supabase Auth)

This replaces the three hardcoded test-account services
(`user_auth_service.dart`, `organizer_auth_service.dart`,
`admin_auth_service.dart`) with real `supabase.auth` calls, while keeping
each service's public method signatures (`login`, `logout`) unchanged so no
screen code needs to change.

**Eventgoer (`user_auth_service.dart`)**
- `login()` → `supabase.auth.signInWithPassword(email: ..., password: ...)`
- On success, fetch the matching row from `public.users` and populate
  `UserSession` (replacing the hardcoded `_testAccount`)
- `logout()` → `supabase.auth.signOut()`, then `UserSession.instance.signOut()`
- Registration screen flow (`registration_screen.dart` →
  `otp_verification_screen.dart` → `identity_verification_screen.dart` →
  `selfie_verification_screen.dart` → `registration_pending_screen.dart` →
  `account_activated_screen.dart`) maps onto:
  - `supabase.auth.signUp(email:, password:)` (Supabase sends its own
    confirmation email by default — decide whether to use Supabase's native
    email OTP or keep a custom OTP screen backed by an Edge Function)
  - ID + selfie upload → `supabase.storage.from('identity_docs').upload(...)`
  - `id_verification_status` stays `'pending'` until an admin approves it
    from the Admin Portal (`admin-organizer-applications.dart` pattern,
    reused for buyer ID review if you add that queue)

**Organizer (`organizer_auth_service.dart`)**
- Same `signInWithPassword` / `signOut` pattern
- On success, load `public.users` (role = `'organizer'`) joined with the
  latest `public.organizer_subscriptions` row → populate `OrganizerAccount`
  via `OrganizerSession`
- Registration submits proof-of-organization to
  `supabase.storage.from('organizer_docs')`; account stays inactive until
  an admin approves (`admin-organizer-applications.dart`)

**Admin (`admin_auth_service.dart`)**
- Same `signInWithPassword` / `signOut` pattern
- Admin accounts are **not self-registered** — pre-seed the one admin
  account directly in Supabase Auth (Dashboard → Authentication → Add
  user), then set `role = 'admin'` on their `public.users` row manually via
  SQL Editor (RLS blocks self-promotion by design — see
  `users_update_own_or_admin` in `policies.sql`)

**Suggested order of implementation:**
1. Eventgoer login/register (most screens already built, most RLS policies
   already cover it)
2. Organizer login/register (unlocks event creation testing)
3. Admin login (manual seed, unlocks the approval queue so organizer/buyer
   verification can be tested end-to-end)

## Phase 2 — Events & Ticket Tiers (Organizer)

- `event_repository.dart`'s in-memory `List<OrganizerEvent>` → replace with
  `supabase.from('events').select()` scoped by `organizer_id = auth.uid()`
  (RLS already enforces this — no manual filtering needed for organizer
  reads, though an explicit `.eq('organizer_id', ...)` is still good
  practice for buyer-facing catalogue queries)
- `organizer-create-event.dart` → `supabase.from('events').insert(...)`
  then `supabase.from('ticket_tiers').insert(...)` for each tier
- Multi-day event sub-event generation (one row per day, linked via
  `parent_event_id`) is best done as an Edge Function so the day-splitting
  logic lives server-side and can't be bypassed by a malformed client
  insert

## Phase 3 — Ticket Purchase, Dynamic QR, PayMongo Sandbox

- Purchase flow needs a Supabase Edge Function (not a direct client
  insert) because it must atomically: decrement
  `ticket_tiers.remaining_quantity`, create the `tickets` row, sign a QR
  token, create the `transactions` row with `escrow_status = 'held'`, and
  call PayMongo Sandbox — all server-side so nothing can be forged
- Dynamic QR rotation (the 60-second re-sign while online, described in
  Chapter III's Technology Stack section) is a good fit for an Edge
  Function invoked from the ticket-wallet screen, using a short-lived
  signed JWT or HMAC token rather than a static value

## Phase 4 — Resale Marketplace + Escrow

- `resale_listing_screen.dart` insert must enforce the 50%–100% price band
  against `ticket_tiers.base_price`; since Postgres CHECK constraints
  can't join across tables, do this validation in an Edge Function (the
  placeholder CHECK in `schema.sql` only rules out negative prices)
- Resale purchase (`resale_checkout_screen.dart`) → another Edge Function:
  transfer `tickets.owner_id`, invalidate + reissue the QR token, update
  `resale_listings.listing_status = 'sold'`, create the resale
  `transactions` row, release the *primary* transaction's escrow status
  logic stays untouched

## Phase 5 — Real-Time Entry Validation (Staff Scanner)

- `organizer-scanner-session.dart` generates a `scanner_sessions` row (PIN
  + token); the Staff scan screens authenticate with the PIN via an Edge
  Function (staff have no Supabase Auth account, matching the original
  design) and write to `qr_scan_logs`
- Supabase Realtime (`supabase.from('qr_scan_logs').stream(...)`) can drive
  a live "Entry Report" view on the organizer dashboard without polling

## Phase 6 — Admin Panel (Approvals, Fraud, Reports)

- `admin-organizer-applications.dart`, `admin-accounts.dart`,
  `admin-resale-monitoring.dart`, `admin-fraud-alerts.dart` all become
  straightforward `supabase.from(...)` reads/writes once `role = 'admin'`
  is set on the signed-in account, since RLS already grants admins full
  access to every table
- Automated refunds-on-cancellation and organizer-fee computation
  (`organizer_fees` table) belong in Edge Functions triggered by an event
  cancellation, not client code

## Notes carried over from the original roadmap

- Escrow, resale price-band enforcement, and QR signing must never be
  client-writable — this is why several tables above have **no** direct
  client UPDATE policy (see `tickets_update_admin_only`,
  `transactions_update_admin_only`, `organizer_fees_write_admin_only` in
  `policies.sql`). All of that logic belongs in Edge Functions running
  with the `service_role` key, which bypasses RLS by design.
- PayMongo integration stays Sandbox-only per the study's stated scope —
  no live payment credentials should be introduced.
