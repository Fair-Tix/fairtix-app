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

## Progress update (this session)

- ✅ `registration_screen.dart`: real form validation (name, email format,
  username, PH mobile number, 13+ age check, password strength/match) +
  calls `UserAuthService.register()`
- ✅ `user_auth_service.dart`: added `register()` (→
  `supabase.auth.signUp` with `full_name`/`username`/`phone`/`birth_date`
  in the metadata `data` map), `verifyRegistrationOtp()` (→
  `supabase.auth.verifyOTP(type: OtpType.signup)`), and
  `resendRegistrationOtp()` (→ `supabase.auth.resend(type: OtpType.signup)`)
- ✅ `otp_verification_screen.dart`: "Verify" calls `verifyRegistrationOtp`,
  "Resend" calls `resendRegistrationOtp`
- ✅ `schema.sql`: added `username` (unique) and `birth_date` columns to
  `public.users`; `handle_new_auth_user()` trigger now populates them (plus
  `phone`) from `auth.users.raw_user_meta_data`
- ✅ `light_pill_field.dart`: added `obscureText`, `suffixWidget`, and
  `errorText` support (used for the new password fields + inline
  validation messages)
- ⚠️ **Action needed in the Supabase Dashboard** for the OTP screen to
  actually receive a 6-digit code instead of a magic link: Authentication →
  Email Templates → "Confirm signup" → change the template to use
  `{{ .Token }}` instead of `{{ .ConfirmationURL }}`
- ⚠️ Since `schema.sql` changed, re-run it (and `policies.sql`) in the
  Supabase SQL Editor — safe to re-run on a project where Phase 1 tables
  haven't been created yet; if they already exist, `alter table
  public.users add column username text unique, add column birth_date
  date;` instead
- ✅ ID upload (`identity_verification_screen.dart`): wired to a real
  Camera/Gallery picker (`image_picker`) and
  `supabase.storage.from('identity_docs').uploadBinary(...)`, storing the
  resulting path + chosen ID type on `public.users`
  (`id_document_url`/`id_type`) and resetting
  `id_verification_status` to `'pending'` via the new
  `UserAuthService.uploadIdentityDocument()`. Reads/writes bytes (not
  `dart:io File`) so the same code path works on mobile and web.
  `pubspec.yaml`, `ios/Runner/Info.plist` (camera/photo-library usage
  strings), and `android/app/src/main/AndroidManifest.xml`
  (CAMERA/READ_MEDIA_IMAGES) were updated to support this.
- ✅ Selfie capture (`selfie_verification_screen.dart`): "Take Selfie"
  now opens the **front camera directly** (no gallery option, since this
  step is meant to be a live capture) via `image_picker`, shows a
  preview with a Retake option, then "Use This Selfie" uploads it to
  the same private `identity_docs` bucket as the ID photo via the new
  `UserAuthService.uploadSelfie()`, recording the path on
  `public.users.selfie_photo_url`.
  - ⚠️ **Not implemented**: any actual face match between the selfie
    and the ID photo, or computing `face_embedding_hash` for duplicate-
    account detection. Both require a server-side model (e.g. a
    third-party face-compare API called from a Supabase Edge Function)
    and are out of scope for a client-only change — this was already
    flagged as later Edge Function work above. Until that exists,
    `id_verification_status` simply stays `'pending'` (set when the ID
    was uploaded) and an admin reviews both photos manually, the same
    pattern already used for organizer applications
    (`admin-organizer-applications.dart`). A buyer-facing equivalent of
    that admin review screen doesn't exist yet either — next backend
    step once this is prioritized.
- ⚠️ Deliberately did NOT add an on-device face-detection package (e.g.
  `google_mlkit_face_detection`) for a "face present in frame" sanity
  check: those plugins don't support Flutter Web, and this pubspec is
  shared with the organizer/admin web build (`flutter run -d chrome`) —
  adding one would break that build entirely, not just degrade
  gracefully.
- ✅ `login_screen.dart` / `user_auth_service.dart`'s `login()`: now calls
  `supabase.auth.signInWithPassword(...)`, then loads the matching
  `public.users` row into `UserSession` via the new `AppUser.fromRow()`
  factory. `AppUser` gained `idVerificationStatus` (`pending` /
  `verified` / `rejected`) and `idDocumentUrl` so the login screen can
  route correctly instead of always going Home:
  - `verified` → `MainShell` (straight into the app)
  - no `id_document_url` yet, or `rejected` → `IdentityVerificationScreen`
    (resume/redo the ID upload step)
  - `pending` with an ID already on file → `RegistrationPendingScreen`
    ("under admin review")
  `logout()` is now `Future<void>` and also calls
  `supabase.auth.signOut()` (was local-session-only before); its one
  call site (`profile_screen.dart`) was updated to `await` it.
  `debugCredentialsHint` is now `''` (was the shared test-account
  string), so the login screen's "Test account: ..." hint box no longer
  renders.
  - ⚠️ Not done in this pass: gating on `role = 'buyer'` (an organizer
    or admin account could technically log in here too, since this only
    checks `auth.signInWithPassword` + loads the `public.users` row
    without checking `role`). Low-priority since the organizer/admin
    portals have their own separate login screens and nothing currently
    links a buyer session to organizer/admin-only actions.
  - ⚠️ Not done: "Forgot Password?" is still a no-op TODO; would map to
    `supabase.auth.resetPasswordForEmail(...)`.
  - ⬜ Organizer/Admin (`organizer_auth_service.dart` /
    `admin_auth_service.dart`) still check hardcoded test accounts —
    same pattern as above applies when those are picked up.

## Progress update (session 2 — organizer registration)

- ✅ `organizer-register.dart`: added an "Organization Name" field, wired
  "Submit Application" to `OrganizerAuthService.register()`, added a
  loading state and inline error text (matching `organizer-login.dart`'s
  style). Only navigates to `OrganizerApplicationSubmittedScreen` on
  success.
- ✅ `organizer_auth_service.dart`: added `register()` →
  `supabase.auth.signUp` with `full_name`/`organization_name`/`role:
  'organizer'` in the metadata `data` map. No OTP step for organizers (no
  such screen exists in this flow) — they confirm via the emailed link
  instead of a code.
- ✅ `schema.sql`: added `organization_name` column to `public.users`;
  `handle_new_auth_user()` trigger now also reads a `role` key from
  `raw_user_meta_data`, but only ever sets `'buyer'` or `'organizer'` —
  never `'admin'` — no matter what a client sends, preserving the
  no-self-promotion guarantee in `policies.sql`.
- ⚠️ Same SQL re-run note as above applies — if `schema.sql` was already
  run before this session, apply just the diff instead:
  ```sql
  alter table public.users add column organization_name text;
  -- then re-run the full `create or replace function
  -- public.handle_new_auth_user()` block from schema.sql
  ```
- ⚠️ Because the "Confirm signup" email template was changed to show
  `{{ .Token }}` for the eventgoer OTP screen, make sure the template also
  still includes `{{ .ConfirmationURL }}` somewhere — organizers have no
  OTP-entry screen and rely on clicking that link to confirm their email.
- ⚠️ Known gap, not fixed in this pass: setting `role = 'organizer'` at
  signup does **not** by itself gate access to organizer-only actions like
  creating events — `is_organizer()` in `policies.sql` only checks `role`,
  not `id_verification_status`. An organizer whose documents haven't been
  approved yet can currently still pass `is_organizer()` checks. Tightening
  this (e.g. a separate `is_approved_organizer()` helper checking both
  `role = 'organizer'` and `id_verification_status = 'verified'`, used on
  `events_insert_own_organizer` / `ticket_tiers` policies) belongs to
  Phase 2/6 once the admin approval screen is wired up.
- ✅ Document uploads (`organizer-register.dart`'s "Proof of Venue
  Booking" / "Valid Event Permit" boxes, session 3): real file picking
  via `file_picker` (`type: FileType.custom`, restricted to
  pdf/jpg/jpeg/png, `withData: true` so bytes load on every platform
  incl. web) replaces the old tap-to-simulate placeholder. On submit,
  `OrganizerAuthService.uploadOrganizerDocument()` uploads each file to
  the private `organizer_docs` bucket and records the path on two new
  `public.users` columns, `venue_proof_url` / `event_permit_url`
  (added to `schema.sql` — these weren't in the original Data
  Dictionary, which only modeled one generic `id_document_url`).
  - ⚠️ **Known gap, same root cause as the buyer OTP requirement**:
    `Supabase.instance.client.auth.signUp()` only returns an active
    session immediately if "Confirm email" is disabled project-wide.
    With confirmations enabled (true here, since the buyer flow relies
    on a confirmation email carrying an OTP token), there's no session
    right after `register()`, and Storage RLS requires one — so the
    documents genuinely **cannot** be uploaded at this point in the
    flow yet. The new `OrganizerAuthService.hasActiveSession` getter
    guards the upload call so this fails safe (registration still
    succeeds; upload is skipped, not silently broken) and will start
    working the moment a session exists at submit time. The real fix is
    a Phase-1/6 follow-up: once organizer login is wired to real
    Supabase Auth, prompt for any still-missing documents right after
    the organizer's first successful login (their `public.users` row
    already tells you whether `venue_proof_url`/`event_permit_url` are
    null) rather than only at registration time — this app doesn't do
    that yet.
  - `schema.sql` changed again — same re-run note as before: if
    `schema.sql` already ran, apply the diff instead:
    ```sql
    alter table public.users
      add column venue_proof_url text,
      add column event_permit_url text;
    ```

## Progress update (session 4 — organizer login)

- ✅ `organizer-login.dart` / `organizer_auth_service.dart`'s `login()`:
  now calls `supabase.auth.signInWithPassword(...)`, verifies
  `public.users.role == 'organizer'` (signs back out and rejects
  otherwise — e.g. a buyer account trying this portal), loads the
  organizer's latest **active** `public.organizer_subscriptions` row (if
  any), and populates `OrganizerSession` via a new `OrganizerAccount`
  built from both. `OrganizerAccount` gained `idVerificationStatus`
  ('pending' / 'verified' / 'rejected') so the login screen can route
  correctly instead of always going to the Dashboard:
  - not `verified` → `OrganizerVerificationPendingScreen` (covers both
    `pending` and `rejected` — there's no separate
    resubmit-documents screen for organizers yet, unlike the eventgoer
    flow's `IdentityVerificationScreen`)
  - `verified` with no active subscription →
    `OrganizerSubscriptionPlanScreen`
  - `verified` with an active subscription → `OrganizerDashboardScreen`
  `logout()` now also calls `supabase.auth.signOut()` (was
  local-session-only before); kept as a synchronous fire-and-forget call
  (not `await`ed) since its one call site, `organizer-profile.dart`'s
  logout confirmation dialog, is a synchronous `onPressed` and
  `unawaited_futures` isn't in this project's lint set, so this doesn't
  need the `async`/`await` treatment the eventgoer version got.
  `debugCredentialsHint` is now `''`, so the login screen's "Test
  account: ..." hint box no longer renders.
  - ⚠️ **Schema gap worked around, not fixed**: `organizer_subscriptions`
    (Table 7) has no plan-name column, only `monthly_fee`. `login()`
    derives the plan name by matching the fee against the Chapter III
    price list (₱299 → Basic, ₱699 → Standard, ₱1,499 → Premium) via a
    new private `_planNameFromMonthlyFee()` helper. This breaks if
    pricing ever changes without a matching code update — a real fix
    would add a `plan_name` (or `plan` enum) column to
    `organizer_subscriptions` in a future schema migration.
  - ⚠️ Not done: nothing yet *writes* to `organizer_subscriptions` for a
    real organizer — `organizer-subscription-plan.dart`'s "Select
    {plan}" button still only calls
    `OrganizerSession.instance.updateAccount(...)` in memory (see that
    screen's `_selectPlan`), so a chosen plan doesn't survive logout
    yet. Wiring that insert is Phase 2 work.
  - ⚠️ Not done: "Forgot Password?" still just shows a snackbar; would
    map to `supabase.auth.resetPasswordForEmail(...)`.
  - ⬜ Admin (`admin_auth_service.dart`) still checks a hardcoded test
    account — same pattern applies when that's picked up.

## Progress update (session 5 — admin login)

- ✅ `admin-login.dart` / `admin_auth_service.dart`'s `login()`: now calls
  `supabase.auth.signInWithPassword(...)`, then confirms
  `public.users.role == 'admin'` for the signed-in account (signs back
  out and rejects otherwise — a buyer/organizer account, or any account
  not yet promoted to admin, can't get in). On success,
  `AdminSession.instance.signIn(...)` is populated with the account's
  real email from `public.users` instead of just echoing back whatever
  string was typed into the form.
  `logout()` now also calls `supabase.auth.signOut()` (fire-and-forget,
  matching the organizer version — its one call site in
  `admin-profile.dart`'s logout dialog is a synchronous handler).
  `debugCredentialsHint` is now `''`, so the login screen's "Test
  account: ..." hint box no longer renders.
  - `admin-login.dart` itself needed **no changes** — unlike the
    eventgoer/organizer logins, there's no "pending verification" state
    for admins to route around, so the existing on-success
    `Navigator.pushReplacement(... AdminDashboardScreen)` already does
    the right thing once `login()` either succeeds or throws.
  - ⚠️ **Admin accounts still don't self-register, by design** (see
    Phase 1 below) — this screen has no sign-up link. Before this login
    can work at all, seed one admin manually: Supabase Dashboard →
    Authentication → Add user, then in the SQL Editor:
    ```sql
    update public.users set role = 'admin' where email = 'the-seeded-email';
    ```
  - ⚠️ Not done: `admin-profile.dart` still has leftover copy from the
    Firebase-era placeholder ("Local Admin Session", "until Firebase is
    connected", "MEMBER SINCE: Not available yet") — cosmetic only, left
    alone since it wasn't required to make login itself work, but worth
    cleaning up alongside a future admin-profile pass.
  - ⚠️ Not done: "Forgot Password?" still just shows a snackbar; would
    map to `supabase.auth.resetPasswordForEmail(...)`.

All three portals (eventgoer, organizer, admin) now authenticate against
real Supabase Auth. What's left of Phase 1 is polish (password reset,
role-gating the eventgoer login against non-buyer accounts) rather than
core wiring — see the individual ⚠️ notes above.

## Progress update (session 6 — manual admin verification workflow)

The eventgoer/organizer upload side (ID, selfie, venue proof, event
permit) and the login-side routing on `id_verification_status` were both
already done (sessions 1–5). What was still missing was the other half:
an admin screen that actually shows pending submissions, lets an admin
look at the uploaded documents, and flips the status to `verified` /
`rejected`. That's now built, entirely on top of existing infrastructure
(RLS in `policies.sql` already allowed admin reads/writes of any user row
and any private-bucket file; the new work was fetching, displaying, and
reviewing it):

- ✅ `models/admin_user_summary.dart` (new): `AdminUserSummary` — one
  `public.users` row shaped for the two admin review screens, plus
  `hasReviewableDocuments` (gates the Review button so it never opens an
  empty dialog).
- ✅ `services/admin_user_service.dart` (new): `fetchUsers({role})` reads
  `public.users` (optionally filtered by role) newest-first;
  `getSignedUrl(bucket, path)` calls `storage.createSignedUrl(...)` — no
  public URLs are ever used, matching both private buckets
  (`identity_docs`, `organizer_docs`); `setIdVerificationStatus()` and
  `setAccountStatus()` write the two status columns admins are allowed to
  touch on someone else's row (via `users_update_own_or_admin`).
- ✅ `widgets/admin_document_viewer.dart` (new): `showAdminReviewDialog(...)`
  — a reusable dialog (used by both admin screens) that fetches a fresh
  signed URL per document, renders images inline and offers a
  copy-signed-link fallback for non-images (e.g. a PDF permit — there's no
  in-app PDF viewer), and shows Approve/Reject (when `currentStatus ==
  'pending'`) or a single Close button otherwise. Handles missing files
  ("Not uploaded yet"), failed signed-URL generation, and failed image
  loads as inline states rather than crashing.
  - ✅ (this pass) Approve/Reject now require a second "Are you sure?"
    confirmation (`_confirmAndAct`) before the Supabase update actually
    runs — previously they fired immediately on tap.
  - ✅ (this pass) Documents lay out side-by-side via `LayoutBuilder` +
    `Wrap` once the dialog has ≥420px to work with (both review flows
    only ever show 2 documents, so this reliably gives the "ID next to
    selfie" / "venue proof next to permit" layout on desktop), and stack
    vertically below that width — same breakpoint style used elsewhere
    (e.g. `organizer-register.dart`'s `isWide` checks). Tapping an image
    now opens it full-screen in an `InteractiveViewer` (pinch/drag zoom)
    instead of only the fixed 220px inline thumbnail.
  - No automated face comparison of any kind is implemented anywhere in
    this dialog or its services, by design — the admin looks at both
    images and decides.
- ✅ `admin-accounts.dart`: real `AdminUserService.fetchUsers()` backs the
  list (was previously a static shell per this task's brief, though the
  fetch/filter/review/suspend wiring in the current file already covers
  everything except the two items above) — role + verification-status
  filter chips, a search box (name/username/email), loading/error/empty
  states with Retry, and Review/Suspend actions per row. Approving/
  rejecting or suspending/reactivating refetches the list so the row's
  new state (and the pending queue) stays accurate without a manual
  refresh, though the refresh button is also there.
- ✅ `admin-organizer-applications.dart`: same pattern, scoped to
  `role = 'organizer'`, with a `verified` status displayed as "Approved"
  (organizer-facing label) rather than the raw enum value. Documents
  reviewed are `venue_proof_url` + `event_permit_url` only — organizer
  registration doesn't currently collect a personal ID
  (`id_document_url`), so that field isn't part of this review; if that
  ever changes, add a third `AdminReviewDocument` here.
- Realtime: no `supabase...stream()` subscriptions exist anywhere else in
  this codebase yet (grep the repo — Phase 5 is the first place one's
  planned, for `qr_scan_logs`), so both screens stick with the same
  fetch-then-refetch-after-mutation pattern already used throughout
  (organizer login, event repository, etc.) rather than introducing a
  one-off realtime channel just for this.

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

> `admin-organizer-applications.dart` and `admin-accounts.dart` are done
> — see "session 6" above. `admin-resale-monitoring.dart` and
> `admin-fraud-alerts.dart` below are still the static/placeholder shells
> this section originally described for all four screens.

- `admin-resale-monitoring.dart`, `admin-fraud-alerts.dart` all become
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
