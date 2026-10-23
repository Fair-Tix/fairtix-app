# Hanz — coding tasks (FairTix)

Status as of Oct 13, 2026. Nothing below has been compiled or run on a device
yet, so Task 0 comes first. Do the tasks in order; each one lists the files,
the steps, and how to know it is done.

Legend: [SQL] = a change to a `supabase/*.sql` file (you run it later in the
Supabase SQL Editor) · [DART] = Flutter code · [EDGE] = Edge Function code.

---

## Task 0 — Make sure the app compiles (5 minutes)

1. Open a terminal in `C:\fairtix-app`.
2. Run `flutter pub get`.
3. Run `flutter analyze`.
4. Fix every line marked **error**. Warnings and "info" can wait.
5. If you can't fix one, paste the full message to Claude.

**Done when:** `flutter analyze` shows no errors.

---

## Task 1 — Resale notifications (#6) · small

**Why:** the manuscript says users are notified of resale listings and sales.
Today only purchases and expiries create a notification.

**Files:** `supabase/resale_functions.sql` [SQL], `lib/models/app_notification.dart` [DART]

Steps:
1. In `list_ticket_for_resale`, after the `update public.tickets ... 'listed'`
   statement and before `return v_listing;`, insert a notification for
   `v_user_id`:
   - title `Ticket Listed for Resale`
   - message like `Your <tier> ticket for <event> is now on the Resale Market at PHP <price>.`
   - type `'resale'`, channel `'in_app'`.
   You need the event title and tier name, so extend the existing
   `select e.status, e.event_start_date ...` query to also read `e.title` and
   `tt.tier_name` into two new variables.
2. In `cancel_resale_listing`, after the ticket is set back to `valid`, insert
   a notification: `Resale Listing Canceled` / `Your listing was canceled and
   your ticket is valid again.` (type `resale`).
3. Open `lib/models/app_notification.dart`, in `AppNotification.fromRow`.
   Check how `type` is mapped. Resale rows must NOT become
   `AppNotificationType.ticketSold` (that type opens the "Ticket Sold" screen
   and needs a ticket id the table doesn't have). Keep them as `general`.

**Done when (after you run the SQL):** listing a ticket, then canceling it,
adds two notifications that show in the bell and open without errors.

---

## Task 2 — Remove the dead purchase-limit code (#8) · small

**Why:** `soldTicketEventIds` is an in-memory set nothing ever fills. The
server now enforces the one-ticket-per-event-day limit.

**File:** `lib/data/sample_tickets.dart`

Steps:
1. Delete `soldTicketEventIds` and `userHasResoldTicketForEvent`.
2. Change `isPurchaseLimitReached(eventId)` to just
   `=> userOwnsTicketForEvent(eventId);`. Add a comment: the server is the real
   check; this only disables the button early.
3. Compile. Fix any file that still referenced the deleted names. Most likely
   `lib/screens/user/notifications_screen.dart` and
   `lib/screens/user/event_details_screen.dart`.

**Done when:** `flutter analyze` is clean and the Buy button still disables for
an event you already hold a ticket for.

---

## Task 3 — Find leftover fee code (#3) · search

**Why:** the buyer now pays exactly the listed price. Anything that still adds
10% on top, or sums `transactions.amount` as organizer revenue, will show
wrong numbers.

Steps:
1. In VS Code press Ctrl+Shift+F and search `kPrimaryPlatformFeeRate`.
2. Then search `withPlatformFee`, then `platform_fee`, then `service_fee`.
3. For each hit, check what it displays:
   - Buyer screens: should show the listed price only. (Already correct if it
     goes through `withPlatformFee`, because the rate is now 0.)
   - Organizer screens (`lib/screens/organizer/*`): any "revenue" figure must
     be the net after FairTix's fee (`organizer_fees.net_amount`, or
     `amount - platform_fee`), not `amount`.
   - Any text that says "includes platform fee" or "service fee": remove or reword.
4. Write down anything you can't decide and ask Mark (organizer dashboards).

**Done when:** no screen shows a fee added on top of the ticket price, and no
organizer screen counts gross as earnings.

---

## Task 4 — Camera and photo permissions (#9) · check

**Why:** the ID and selfie upload will crash or do nothing without them.

1. `android/app/src/main/AndroidManifest.xml`: inside `<manifest>` and above
   `<application>`, there must be
   `<uses-permission android:name="android.permission.CAMERA" />`.
2. `ios/Runner/Info.plist`: there must be both keys with a sentence of text:
   `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
3. Run the registration flow on a phone: upload an ID and take a selfie. Both
   must reach Supabase Storage (`identity_docs` bucket) and set
   `id_document_url` / `selfie_photo_url` on your `users` row.

---

## Task 5 — Resale purchase (#7) · the big one

Goal: replace the fake resale checkout with a real one. A buyer pays the
listing price through PayMongo; the ticket moves to them with a NEW QR code;
the seller is paid the price minus FairTix's flat 5%.

### 5.0 Decide these first (10 minutes, with the team)

- Can a free (PHP 0) ticket be resold? Simplest rule: **no**. Add a check in
  `list_ticket_for_resale`: `if v_ticket.purchase_price <= 0 then raise exception
  'Free tickets cannot be resold.'`. This avoids a zero-amount resale payment.
- Who pays the 5%? The manuscript says it comes out of the **seller's**
  proceeds; the buyer pays only the listing price. Build it that way.

### 5.1 [SQL] `supabase/resale_purchase.sql` (new file)

Run it after `resale_functions.sql`, `checkout_guard.sql`, `purchase_functions.sql`.

1. `resale_market()` — returns active listings for the market screen. Make it
   `security definer` and return: `listing_id, ticket_id, listing_price,
   original_price (tickets.purchase_price), tier_id, tier_name, event_id,
   event title / venue / event_start_date, seller_id, seller first name`.
   Why a function: the `users` table is not readable by other users under RLS,
   so the seller's name can't be joined from the app. Call
   `expire_resale_listings()` at the top, and only return `active` listings of
   `published` events.
2. `resale_checkout_quote(p_listing_id uuid, p_buyer_id uuid)` — same idea as
   `checkout_quote`. Raise plain-sentence errors if: the listing isn't active;
   the event isn't published or is past its 24-hour cutoff; the buyer is the
   seller; `ticket_slot_used(p_buyer_id, event_id)` is true. Return the listing
   price. Revoke from `public, anon, authenticated` (service role only).
3. `_do_resale_purchase(p_listing_id uuid, p_buyer_id uuid, p_qr_code_token text)`:
   - Idempotency: if a ticket already has `qr_code_token = p_qr_code_token`,
     return it (same pattern as `_do_ticket_purchase`; the Edge Functions can
     run twice for one payment).
   - Lock the listing row (`for update`), require `listing_status = 'active'`.
   - Lock the ticket row; take `pg_advisory_xact_lock` on buyer + event, then
     re-check idempotency, then `ticket_slot_used(buyer, event)`.
   - Move the ticket: `owner_id = buyer`, `qr_code_token = p_qr_code_token`
     (new token, so the seller's old QR/screenshot is dead), `qr_status =
     'active'`, `ticket_status = 'valid'`, `used_at = null`. Do NOT call
     `reissue_ticket_qr` — users can't call it, and you set the token yourself.
   - Listing: `listing_status = 'sold'`, `sold_at = now()`, `escrow_status =
     'released'`.
   - Insert a `transactions` row: `transaction_type 'resale'`, `buyer_id =
     buyer`, `seller_id = seller`, `amount = listing_price`, `platform_fee =
     round(listing_price * 0.05, 2)`, `status 'completed'`, `escrow_status
     'released'`, `escrow_amount 0`.
   - Notifications (type `'resale'`, in-app): seller `Ticket Sold` (price and
     what they receive after the 5%); buyer `Resale Ticket Purchased`.
   - Keep `tickets.purchase_price` unchanged (it stays the ORIGINAL price, which
     is what caps any later resale).
4. `fulfill_resale_purchase(...)` — thin wrapper, revoked from
   `public, anon, authenticated`, exactly like `fulfill_ticket_purchase`.

### 5.2 [EDGE] reuse the existing payment functions

Fewer deploys: extend, don't copy.

- `supabase/functions/paymongo-checkout/index.ts`: accept `listingId` as an
  alternative to `tierId`. If `listingId` is present, call
  `resale_checkout_quote` instead of `checkout_quote`, and put
  `{ listing_id, buyer_id }` in the link `remarks`.
- `supabase/functions/paymongo-verify/index.ts` and
  `paymongo-webhook/index.ts`: after reading the link `remarks`, if
  `remarks.listing_id` exists call `fulfill_resale_purchase` (token
  `FTX-RS-<linkId>`), otherwise the existing `fulfill_ticket_purchase`.
  Return `{ ticket_id, qr_code_token }` the same way.
- Keep the rule that the price comes from the server and the buyer must match
  `remarks.buyer_id`.

### 5.3 [DART] services

`lib/services/resale_repository.dart`:
1. Add a `MarketListing` model (the fields from `resale_market()`).
2. Add `Future<List<MarketListing>> fetchMarket()` calling `rpc('resale_market')`.

### 5.4 [DART] screens

1. `lib/screens/user/resale_market_screen.dart` + `lib/data/sample_resale_listings.dart`:
   load from `fetchMarket()` with loading / error / empty states and
   pull-to-refresh. Hide or disable the Buy button on your own listings and on
   events where `isPurchaseLimitReached(eventId)` is true. Stop using
   `sampleResaleListings`.
2. `lib/screens/user/resale_checkout_screen.dart`: copy the payment flow from
   `checkout_screen.dart` (create link → open browser → "I've Completed
   Payment" → verify), but call `paymongo-checkout` with `{ listingId }`.
   After success, refresh `TicketRepository`, `TransactionRepository`,
   `NotificationRepository`, and the market list, then go to the confirmation
   screen. Delete the 900 ms fake delay and the `sampleMyTickets.add` call.
3. `lib/models/transaction.dart`: a resale purchase receipt shows the amount the
   buyer paid. The seller's receipt already shows amount minus fee.

### 5.5 [SQL] refunds must follow the current holder

`supabase/refund_functions.sql`, the event-cancel trigger: today it refunds
every completed `purchase` transaction to the original buyer. After resale it
must refund only the **latest completed transaction per ticket** (purchase or
resale) to that transaction's `buyer_id`. Earlier completed transactions are
not clawed back (manuscript, Refund Policy). Also cancel any active listing
(already done).

### 5.6 Test script (do all of it)

Use two accounts: A (seller) and B (buyer), both verified.
1. A buys a ticket. A lists it at 80%.
2. B opens the Resale Market and sees it. A cannot buy their own listing.
3. B pays through PayMongo, taps "I've Completed Payment".
4. B's My Tickets shows the ticket with a **new** QR; A's wallet no longer has it.
5. Scan A's old QR at the scanner: must be rejected. Scan B's: accepted.
6. A and B both have a notification. A's receipt shows price minus 5%.
7. A tries to buy another ticket for the same event: refused (slot not returned).
8. B tries to buy a second ticket for that event: refused.
9. Cancel the event: the refund goes to **B**, not A.
10. In Table Editor: `resale_listings` row is `sold`; `transactions` has a
    `resale` row with `platform_fee = 5%`.

**Done when:** all ten checks pass and no `sampleResaleListings` /
`sampleMyTickets` writes remain in the resale code.

---

## Task 6 — Scanner `search_path` fix (John Nino's file) · tell him first

**File:** `supabase/scanner_functions.sql`

On Supabase, `gen_random_bytes` lives in the `extensions` schema. Two functions
set `search_path = public`, so they probably can't find it and generating a
scanner link fails.
1. Message John that you're changing his file.
2. In `generate_scanner_session` and `reissue_ticket_qr`, change
   `set search_path = public` to `set search_path = public, extensions`.
3. Later, in the Supabase SQL Editor, run the file and test "Generate scanner
   link" from the organizer app.

---

## Task 7 — Polish (only if time)

- Free-ticket receipt: `lib/models/transaction.dart` sets `paymentMethod` to
  `'PayMongo Sandbox'` always. Use `'Free ticket'` when the amount is 0, and
  make the note in `transaction_detail_screen.dart` match.
- iPhone screenshot blocking: add the `screen_protector` package and call it in
  `lib/services/screen_protection.dart`. Only worth doing if someone tests on
  an iPhone.

---

## Waiting on the team (do not code yet)

- Refund behavior: automatic, or admin clicks "Mark Processed"? The manuscript
  says automatic.
- Escrow: purchases are recorded as already released; the manuscript holds
  funds until the QR is scanned. Overlaps with John Nino's scanner work.
- Rotating QR tokens every 60 seconds: today the token is static. Needs a
  design agreed with John Nino.
- Announcements (Mark) and platform settings (Heron) have no Supabase service.

---

## Supabase work you do later, in this order

1. `schema.sql` 2. `policies.sql` 3. `checkout_guard.sql`
4. `purchase_functions.sql` 5. `purchase_notification.sql`
6. `scanner_functions.sql` 7. `resale_functions.sql`
8. `resale_purchase.sql` (new, Task 5) 9. `fee_model_migration.sql` (optional)
10. `revenue_functions.sql` 11. `refund_functions.sql` 12. `report_functions.sql`
13. `organizer_report_functions.sql` (organizer export, Standard/Premium only)
14. `admin_overview_functions.sql` 15. `fraud_alerts.sql` 16. `security_patch.sql`
17. `push_notifications.sql` (turns on Realtime for notifications; after `notification_functions.sql`)

Then redeploy the Edge Functions `paymongo-checkout`, `paymongo-verify` and
`paymongo-webhook`, and confirm the `PAYMONGO_SECRET_KEY` secret is set.
