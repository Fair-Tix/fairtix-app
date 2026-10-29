# FairTix Progress

## Current status
Step 1 (access restrictions): UI gating in My Events + Dashboard done, backend SQL hardened in file. NOT compiled, NOT applied in Supabase, NOT manually tested.
Steps 2-4: code review (2026-10-27) found scanner link/QR/PIN, session persistence/revoke, Forgot Password, Announcements already implemented. Still unverified (no run).
Step 5 (revenue/refund consistency): audited, one discrepancy fixed (see below). Not compiled/run.
Next: Steps 6-9 (see Remaining).

## Step 5 audit result (2026-10-28, code + SQL read only)
Consistent already:
- Dashboard "Total revenue", Analytics "Your net share" and Escrow held+released all use `organizer_escrow_overview()` (net = amount - platform_fee actually charged per purchase). `organizer_tier_sales()` and `get_event_summary()` use the same rules (purchase whose ticket is `canceled` counts as refunded, not sold). Per-tier gross/fee are real transaction amounts, not price x plan rate, and refunds come off the tier they were bought in.
- Dashboard revenue falls back to a plan-rate estimate ONLY if the escrow RPC fails (labelled "Estimate").
Fixed:
- Dashboard event cards showed inventory sold (`total_quantity - remaining_quantity`); `cancel_event` never restores `remaining_quantity`, so canceled events kept showing refunded sales while Analytics showed 0. Cards now use net-of-refund sold per event from the escrow overview (falls back to inventory if unavailable).
Not changed (noted):
- Featured card and My Events cards still use inventory sold (only differs for canceled/refunded events; My Events screen not checked).
- Escrow "Release date" for multi-day events shows the last day + 1 though money releases per day.
- `refund_functions.sql` makes refunds `pending` until an admin runs `admin_process_refund`; proposal says fully automatic. Refunds also go to the ORIGINAL buyer (transactions.buyer_id), not the current holder after resale as the proposal states. Needs a decision.

## Completed tasks
None verified yet (nothing compiled or run).

## Files changed
- `lib/screens/organizer/organizer-my-events.dart`: access gating on create/manage/cancel (earlier session).
- `lib/screens/organizer/organizer-dashboard.dart`: `_manage` requires approval + active plan, `_cancel` requires approval (`ensureOrganizerAccess`); event cards use net sold (`_soldByEvent`, `sold` param on `_EventCard`).
- `supabase/organizer_event_functions.sql`: `update_event_details` and `cancel_event` now reject non-admins who are not `verified` + `active` (expired plan may still cancel, by design). MUST be re-run in the Supabase SQL Editor to take effect.
- `FAIRTIX_PROGRESS.md`.

## Tests and results
- None run. No flutter toolchain/shell available from this chat.

## Manual tests needed
1. `flutter analyze` (watch `organizer-dashboard.dart`: new `sold` param, async `_manage`/`_cancel`).
2. Re-run `organizer_event_functions.sql` in Supabase; then as a rejected/suspended organizer try update_event_details and cancel_event via the app: expect the new error messages.
3. Pending organizer: Create/Manage/Cancel (My Events AND Dashboard) show lock dialog. Rejected: dialog mentions support. Expired plan: Create/Manage locked, Cancel opens. Active: all open.
4. Cancel an event with sales: Dashboard card shows 0 / N, matching Analytics; Dashboard tickets-sold tile, Analytics "Tickets sold" and Escrow ticket counts agree; revenue = Analytics net = Escrow held+released.
5. Steps 2-4: scanner link + QR + PIN autofill, revoke, Forgot Password (Supabase "Reset password" template must use `{{ .Token }}`), announcements (needs `organizer_tools.sql`, `notification_functions.sql` applied).

## Remaining tasks (priority order)
1. Compile + manual tests above.
2. Verify Steps 2-4 at runtime; confirm `scanner_sessions` columns used by `list_my_scanner_sessions` (schema.sql not read).
3. Step 6: announcement delivery (already wired; verify).
4. Step 7: support contact + rejected organizers (contact support, re-upload documents).
5. Step 8: dark-mode fixes; subscription end date + plan limits display.
6. Step 9: notification preferences if required; before deleting `organizer-subscription.dart`, `organizer-revenue-report.dart`, `organizer-verification-pending.dart.old`, search for references to each.
7. Decide on refund-flow mismatches above.

## Important decisions
- Cancel requires approval only (not subscription), on purpose.

## Step 7 (support contact + rejected organizers) - 2026-10-28, NOT compiled/run
Done in code:
- Rejected organizer login now routes to `OrganizerDocumentUploadScreen(resubmit: true)` (both docs re-uploaded, then `resubmit_organizer_application()` sets status back to 'pending'). Screen also has "Skip for now (browse only)" and, when configured, "Contact FairTix support".
- Locked-feature dialog (`access_control.dart`) for a rejected organizer now offers "Resubmit documents" (+ "Contact support" when configured).
- New `supabase/organizer_resubmit.sql` (MUST be run in Supabase). New `OrganizerAuthService.resubmitApplication()`.
- Files: `organizer-login.dart`, `organizer-document-upload.dart`, `access_control.dart`, `organizer_auth_service.dart`.
BLOCKER (needs the user): `FairTixSupport.email` in `lib/services/support_contact.dart` is empty (TODO). The official FairTix support address is not in the project; I did not invent one. Until it is set, the support buttons are hidden and the Help & Support "Contact Support" (eventgoer app) is still `SimplePlaceholderScreen`.
Manual tests: reject an organizer in Admin, log in -> resubmit screen; upload both docs -> status 'pending' and "Application submitted" screen; Admin sees it in Applications again; rejected organizer pressing Create Event on Dashboard -> dialog with Resubmit documents.

## Step 8 (dark mode + subscription end date / plan limits) - 2026-10-29, NOT compiled/run
Subscription end date + plan limits: NOT missing. `organizer-subscription.dart` (OrganizerSubscriptionScreen) already shows plan, price, "Current period ends <date>", expired date, events/month, tickets/day, days per multi-day event, platform fee, export, benefits; the plan screen shows "renews <date>". Data comes from `OrganizerAccount.subscriptionRenewsAt/ExpiredAt` + `subscription_plans`. It is reachable from the profile menu via `organizer-scaffold.dart`, so it is IN USE: DO NOT DELETE it in Step 9. Needs a runtime check only.
Dark mode: legacy light-only widgets (`AppColors`/`AppTextStyles`, white cards, white input fills) made theme-aware with `FairTixPalette`:
- `app_colors.dart` (`AppTextField`), `organizer-form-widgets.dart` (venue + tier dropdowns)
- `organizer-create-event.dart`, `organizer-edit-event.dart`, `organizer-cancel-event.dart`, `organizer-event-created.dart`, `organizer-event-edited.dart`, `organizer-event-cancelled.dart`
NOT checked for dark mode (not read): `organizer-my-events.dart`, `organizer-scanner-session.dart`, `organizer-send-announcement.dart`, `organizer-change-password.dart`, `organizer-help.dart`, `organizer-forgot-password.dart`, `organizer-otp-verification.dart`, `organizer-register.dart`, `organizer-public-landing.dart`. Also left as-is: purple banner placeholder icon `Colors.white70` in edit-event (low contrast in light mode).
Files also touched for Step 8: none other.
Manual dark-mode test: toggle dark mode, open Create Event, Edit Event, Cancel Event, and the Published/Updated/Cancelled screens; fields, labels, cards and dialogs should be dark with readable text; light mode should look as before.

## Step 9 notes (2026-10-29)
- `organizer-subscription.dart`: KEPT. Imported by `organizer-scaffold.dart`; it is the Subscription page. Do not delete.
- `organizer-revenue-report.dart`: not imported by main.dart, scaffold, dashboard, analytics, my-events, profile, settings, help, login or the export button (read manually; no project-wide grep available). Renamed to `organizer-revenue-report.dart.old` (reversible) instead of deleted. If `flutter analyze` shows no "URI doesn't exist" error, delete the `.old` file by hand. If it does, rename it back.
- `organizer-verification-pending.dart.old`: not Dart-compiled, nothing can import it. This chat has no delete tool; delete it by hand.
- Not checked for an import of the revenue report: organizer-escrow, scanner-session, send-announcement, change-password, forgot-password, otp, register, public-landing, landing, account-approved, application-submitted, subscription-*, admin screens. `flutter analyze` will reveal any.
- Notification preferences: NOT implemented (needs a decision + SQL + server-side filtering; Settings page currently states they are not available).
- Known leftover: My Events cards and its "Tickets sold" tile still use inventory sold (not net of refunds) for canceled events; Dashboard was fixed, My Events was not.

## Update 2026-10-29 (after user's reply)
- Support email set: `FairTixSupport.email = 'fairtix.support@gmail.com'` (the Step 7 blocker is resolved; support buttons now show). Help & Support (eventgoer) screen still placeholder.
- `flutter analyze` (user ran): 6 issues, none errors. Fixed the one caused by my change (`access_control.dart:175` unnecessary `!`). The other 5 are older: unused_element_parameter (`organizer-public-landing.dart:645` gap, `organizer_top_menus.dart:931` trailing), doc-comment angle brackets (`organizer-subscription-plan.dart:14`), deprecated `dart:html` (`file_save_web.dart`), `use_null_aware_elements` (`organizer_account_ui.dart:73`). Left alone.
- User ran `organizer_event_functions.sql` and `organizer_resubmit.sql` (reported "Done" for items 3 and 4).
- DECISION: refunds are AUTOMATIC and go to the CURRENT holder. Implemented in `supabase/refund_functions.sql` (NOT yet run, NOT tested): trigger on event cancel now creates 'processed' refunds (latest completed purchase/resale per ticket = current holder), marks them 'refunded', closes original purchase escrow, withholds organizer fee, keeps a resold ticket's original purchase status 'completed' (so the original buyer gets no false "Refund issued"), plus a one-time backfill that processes old 'pending' refunds. `admin_process_refund` kept for compatibility. Admin refund screens that show a 'pending' queue will now be empty. Not verified: the `trg_notify_transaction` body (notification_functions.sql), which sends "Refund issued" on status -> 'refunded'; admin refund log UI.
- `lib/screens/user/notifications_screen.dart` (shared by eventgoer/organizer/admin "view all notifications"): was light-only, cards stretched edge to edge on web. Now uses `FairTixPalette` (dark mode OK) and is centered with max width 820. NOT compiled/run. It is still a standalone page (no organizer sidebar).
- Organizer Profile: removed the "Security" (Change password) card; it already lives on Settings > Sign-in & security. Edited `organizer-profile.dart` (not compiled).
- Manual tests still NOT done: access restrictions (1), revenue after cancel (5), resubmission (7), dark mode (8) + remaining unchecked screens.

## Exact next step
User: run `supabase/refund_functions.sql` in the SQL Editor, then cancel a test event that has a normal purchase and a resold ticket and check: refunds rows are 'processed', buyer/current holder got the notification, Analytics/Escrow/Dashboard agree, Admin refund log looks right. Then run the pending manual tests and send results. Later: notification preferences (still undecided), My Events net-sold fix, dark mode on remaining screens.
