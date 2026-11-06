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

## UI rework: Transactions screens (2026-11-05), NOT compiled/run
Rebuilt in the dark design from the mockups, following the existing Ft* system (`FtAuthTheme`, `FtPageHeader`, `FtSubpageScaffold`); both screens follow the Light/Dark switch.
- `lib/screens/user/transactions_screen.dart`: All/Purchases/Sales/Refunds chips, one grouped card (type, event · date, amount, status badge), footer count, pull-to-refresh kept.
- `lib/screens/user/transaction_detail_screen.dart`: amount + status card; Event, Date, Paid with, Buyer fees (resale fee for a sale; none for refunds), Reference with copy button.
- NEW `lib/widgets/ft_transaction_ui.dart`: `FtTransactionStatusPill`, `formatPesoShort`.
- `lib/models/transaction.dart`: added `formatShortDate`, `formatMediumDate`.
- Not done: mockup's "Escrow: Held until <date>" row (model/RPC has no escrow or release date). `TransactionTile` is now unused by the list (left in place).
- Still to restyle from the mockups: Help & Support, Resale listing/checkout/market, Notifications, Notification preferences, Ticket listed/sold confirmations.
- Manual test: `flutter analyze`, open Profile > Transactions, try each filter, tap a row, tap the copy icon, toggle Light mode.

## Admin UI redesign (2026-11-05) - Phase 1 done in code, NOT compiled/run
Goal: admin looks like the organizer (Plus Jakarta Sans, FairTixMark, pill nav, gradient active state, 1600px content, fade-in).
- `lib/widgets/admin_shell.dart`: rewritten. Wide (>=1280px): logo + ADMIN chip, centered pill nav (9 items, short labels), ThemeModeSwitch, bell, gradient avatar menu. Narrower: menu button opens a styled Drawer (full labels, theme switch, account/logout). Phones (<700px): mark-only logo, theme toggle moves into avatar menu. Public API unchanged (`active`, `title`, `body`, `AdminNavItem`). Old `_Sidebar` removed.
- `lib/widgets/admin_widgets.dart`: AdminBadge (11px, Jakarta), AdminCard (radius 24, organizer shadow), AdminEmptyState (icon circle), AdminErrorBox, AdminSummaryCard (taller, 28px value), AdminSummaryRow spacing, `adminHeaderStyle` 9 -> 11px.
- Phase 2 (in progress, NOT compiled/run): per-screen polish of `lib/screens/admin/`. DONE in code: `admin-dashboard.dart` (AdminPageHeader, palette/Jakarta text, themed panels) and `admin-organizer-applications.dart` (rewritten: filter chips with counts, themed table, AdminBadge/AdminRowAction, dead private sidebar/top bar/logo/logout removed; date now via `formatAdminDate`). New shared widgets in `admin_widgets.dart`: `AdminPageHeader`, `AdminHeaderButton`, `AdminFilterChips`, `AdminRowAction`. ALSO DONE (2026-11-05, not compiled): `admin-user-registrations.dart` and `admin-accounts.dart` rewritten on the shared widgets (new in admin_widgets: `AdminSearchField`, `AdminTableHeader`, `adminCell()`, `AdminTableRow`, `AdminRowAction.color`). Accounts: the search box was in the old unused top bar so searching never worked; a search field now sits above the table (also on Registrations); role filter is now chips; dead sidebar/top bar/logo/logout removed; dates via `formatAdminDate`. ALSO DONE (not compiled): `admin-events-tickets.dart` and `admin-resale-monitoring.dart` (status filters now chips with counts + search field; actions are pills; dialogs use new `AdminDialog`/`AdminDialogText`/`AdminDialogButton`/`adminInputDecoration`; `AdminToggleChip` for 'Near floor only'). Events table goes wide at 900px (was 760) because the action column is larger. ALSO DONE (2026-11-05, batch 3, styling only, NOT compiled): `admin-fraud-alerts.dart` (AdminPageHeader + refresh/export buttons, filter chips with counts, AdminTableHeader/Row at >=900px, review dialog themed; 'Resolve' is now the purple gradient button instead of green) and `admin-revenue-reports.dart` (range selector is now AdminFilterChips, export dropdown themed, all panels/tables on shared widgets, tables scroll sideways below their min width (560/620/820px) instead of squeezing, 'Mark refund processed' uses AdminDialog, export cards use AdminHeaderButton). Both: AppColors/AppTextStyles and the private `adminHeaderStyle` use removed, no service/SQL/logic changes. REMAINING: none of the listed screens; next is verification only. ALSO DONE (2026-11-05, batch 5, styling only, NOT compiled): `admin-announcement.dart` (AdminPageHeader/AdminCard/AdminHeaderButton, palette inputs, warning banner themed; dead sidebar/top bar/logo/logout removed; still highlights 'Dashboard' in the shell) and `admin-login.dart` (rewritten to match organizer login: brand panel + ADMIN chip left, 420px form right, TopGlowBackground, ThemeModeSwitch top-right, gradient Log In button, no card; `PrimaryButton`/AppColors removed; login/validation/error logic unchanged; email hint typo 'Email Adress' now 'Email address'). Behavior note: Announcement screen is not in the nav; check how it is opened (not verified). ALSO DONE (2026-11-05, batch 4, styling only, NOT compiled): `admin-platform-settings.dart`, `admin-subscription-plans-card.dart`, `admin-profile.dart` (shared AdminPageHeader/AdminCard/AdminHeaderButton, palette + orgText, inputs rounded 14 with palette borders, dead sidebar/top bar/logo/logout/_navigate + unused imports removed; profile date via `formatAdminDate`, replacing `formatFriendlyDate`). NOTE (unchanged logic, pre-existing): Platform Settings General/Payment/Security/Notifications 'Save Changes' only show a snackbar and keep values in memory (nothing is persisted); only the Subscription Plans card saves to Supabase. Profile 'View Full Log' is plain text with no action. Likely leftovers in remaining screens: duplicate private sidebars (unused after the shell), AppColors/AppTextStyles, 9-12px fonts.
- Manual checks: `flutter analyze`; each admin page in light + dark at ~1400px (pill), ~1000px (drawer), phone width; watch tables for overflow after the header font bump (`adminHeaderStyle` 11px) and pill fit at 1280-1360px. If the pill looks cramped, raise `_pillBreakpoint` in `AdminShell`.

## Admin top bar: Settings in profile dropdown + organizer-style dropdowns (2026-11-05), NOT compiled/run
- `lib/widgets/admin_shell.dart`: 'Platform Settings' removed from the pill nav (now 8 items; still in the mobile Drawer and still reachable at `AdminNavItem.platformSettings`). Bell is now `OrganizerBellButton` (dropdown with All/Sales/Events/System tabs, latest 6, Mark all read, View all -> `NotificationsScreen`). The avatar `PopupMenuButton` is replaced by `_AccountMenu` (StatefulWidget) opening `_AdminProfilePanel`: header card (Administrator, email, Admin chip, initial avatar), Profile, Settings, Light/Dark mode (phones only), Sign out. Ring shows while open or on Profile/Settings pages.
- `lib/widgets/organizer_top_menus.dart`: added public `showTopMenuDropdown`, `topMenuPanelDecoration`, `TopMenuItem` (thin wrappers over the existing private helpers; organizer behavior unchanged).
- `notification_bell.dart` is no longer used by admin_shell (still exists; check other users before deleting).
- Notes: the dropdown tabs/empty-state text are organizer-worded (sales/events); admin-specific tabs not done. Manual checks: `flutter analyze` (watch for unused import/`_adminNavLabel` 'Settings' case, harmless), then at ~1400px/1000px/phone in light + dark: bell dropdown, avatar dropdown, Settings navigation, Sign out dialog, pill fit now that it has 8 items (breakpoint left at 1280).

## Admin Profile + Platform Settings layout (2026-11-05), NOT compiled/run
- `admin-platform-settings.dart`: wide layout is now two balanced columns (General + Notifications | Payment + Security); narrow stacks General, Payment, Security, Notifications; Subscription Plans card unchanged below. Card icons fixed (General `tune_rounded`, Payment `payments_outlined`). No logic changes (Save Changes still only shows a snackbar, nothing persisted).
- `admin-profile.dart`: password card is now Current Password row, then New (+ strength bar) and Confirm side by side (>=560px card width, stacked below), divider, then note + Save footer. Removed the 400px field caps (the two `ConstrainedBox`es became no-op `Padding(EdgeInsets.zero)` wrappers in `_passwordField`/`_strengthIndicator`, safe to simplify later). Removed duplicate ROLE row and the dead 'View Full Log' link (`_PanelHeader.action` param deleted). Password change logic untouched.
- Manual checks: `flutter analyze`; Profile and Settings in light + dark at ~1400px, ~1000px (900px is the wide/stack switch) and phone width; submit a wrong current password and a valid change to confirm the form still validates/saves.

## Admin Subscription Plans card redesign (2026-11-05), NOT compiled/run
- `admin-subscription-plans-card.dart`: UI rewritten, logic unchanged (`_load`, `_buildPlans` validation, `_save`, `_PlanDraft`, `_parseLimit`, `_trimNumber` kept verbatim). Plans are now side-by-side editor cards (3 columns >=1080px of inner width, 2 >=640px, else 1; rows share the tallest card's height via `IntrinsicHeight`), each with Active/Off + 'Not saved yet' pills, move left/right, remove (unsaved only), on/off switch, name + badge, PRICING (monthly price, platform fee), LIMITS rows (blank = unlimited), export switch, benefits box. Off plans are dimmed. Dashed 'Add plan' tile ends the grid (the footer 'Add Plan' button is gone; footer keeps the note + Save Changes). Header shows '<n> plans · <m> active'.
- Manual checks: `flutter analyze`; light + dark at ~1400/1000/phone width; watch for layout errors from `IntrinsicHeight` + TextFields (if any, swap the row for a `Wrap`); edit a plan, add one, reorder, toggle off, Save, reload and confirm it persists and the organizer plan screen shows the change; try Save with a price under ₱20 and with every plan off (should show the same validation messages as before).

## Admin dashboard header buttons (2026-11-05), NOT compiled/run
- `admin_widgets.dart`: new `AdminIconButton` (40x40 outlined icon-only button with tooltip; shows a spinner while `loading`).
- `admin-dashboard.dart`: header actions are now one centered Row: refresh icon button (tooltip 'Refresh data', spinner while loading, no text) then the filled 'Create Announcement' button on the right edge. The activity empty-state hint now says 'Use the refresh button'. Other screens' text 'Refresh' buttons were converted afterwards (see next section).
- Manual check: `flutter analyze`; dashboard at wide/phone width in light + dark; tap refresh (spinner shows, data reloads), Create Announcement still opens the announcement screen.

## Admin header: icon-only refresh on all pages + actions flush right (2026-11-05), NOT compiled/run
- `admin_widgets.dart` `AdminPageHeader`: on wide screens (>=700px) the action group was in a `Flexible` slot that shares free space 50/50 with the title, so buttons floated mid-header. It is now a content-sized `ConstrainedBox(maxWidth: 560)` after the title `Expanded`, so actions sit flush against the right edge on every admin page. Narrow layout unchanged.
- Text 'Refresh' / 'Refreshing...' `AdminHeaderButton` replaced by `AdminIconButton` (icon only, tooltip 'Refresh data', spinner while loading, disabled while loading) in: `admin-events-tickets.dart`, `admin-fraud-alerts.dart`, `admin-resale-monitoring.dart`, `admin-accounts.dart`, `admin-organizer-applications.dart`, `admin-user-registrations.dart`, `admin-revenue-reports.dart` (spinner/disable covers all three of its loaders; it was previously never disabled). Dashboard already icon-only. Platform Settings, Profile, Announcement have no refresh.
- Button order unchanged (refresh icon first in each group; on Dashboard before 'Create Announcement').
- Manual check: `flutter analyze`; each admin page wide/phone width, light + dark: refresh icon, buttons flush right, hover tooltip.

## Admin Browse Published Events (2026-11-05), NOT compiled/run
- New `lib/screens/admin/admin-browse-events.dart` (`AdminBrowseEventsScreen`): admin-styled, view-only catalogue inside `AdminShell` (top bar, 1600px content, light/dark), search by event/venue, table (Event, Date, Venue, From price, View) that becomes stacked cards under 760px, refresh icon, 'Back to Events & Tickets' button. Reads `PublicEventRepository` and opens `EventDetailsScreen(readOnly: true)` on View.
- `admin-events-tickets.dart`: 'Browse Published Events' now opens it instead of `AllEventsScreen(readOnly: true)` (import swapped).
- `AllEventsScreen(readOnly: true)` light layout is untouched; the organizer portal may still use it (not checked). `EventDetailsScreen` read-only view is unchanged and still has its own (non-admin) layout.
- Note: the 'Events' pill is the active item, so clicking it does nothing; use the Back button. Other pills navigate away normally.
- Manual check: `flutter analyze`; open from Events & Tickets at wide/drawer/phone widths, light + dark; search, refresh, View an event, Back.

## Admin Create Announcement modal (2026-11-05), NOT compiled/run
- `admin-announcement.dart` rewritten: new `showAdminAnnouncementDialog(context)` (modal: title, close X, form, platform-wide notice; closes itself after a successful send) and a shared `AdminAnnouncementForm` (same fields, validation and `AdminUserService.sendAnnouncement` call as before). `AdminAnnouncementScreen` is kept (same class name) and now uses the shared form, in case something else references it; the Dashboard no longer opens it.
- Behavior change: the result snackbar now shows even if the modal was closed mid-send (messenger captured before the request).
- `admin-dashboard.dart`: 'Create Announcement' calls `showAdminAnnouncementDialog`.
- Manual check: `flutter analyze` (dashboard may report the `admin-announcement.dart` import as still needed: it is); open the modal wide/phone, light + dark; empty submit shows both validation errors; send closes the modal and shows the count snackbar; X / tapping outside closes without sending.

## Exact next step
User: run `supabase/refund_functions.sql` in the SQL Editor, then cancel a test event that has a normal purchase and a resold ticket and check: refunds rows are 'processed', buyer/current holder got the notification, Analytics/Escrow/Dashboard agree, Admin refund log looks right. Then run the pending manual tests and send results. Later: notification preferences (still undecided), My Events net-sold fix, dark mode on remaining screens.

## UI rework: eventgoer mockups, part 2 (2026-11-05), NOT compiled/run
Restyled to the dark mockups (Plus Jakarta Sans, `FtAuthTheme`, follow the Light/Dark switch). Logic unchanged unless noted.
- `help_support_screen.dart`: expandable FAQ card (5 answers, written from the project's rules: 50-100% band, 5% seller fee, new QR on resale, refunds to current holder), "Still need help?" card with the real support email (tap = open mail app, falls back to copying), Terms & Privacy row kept. Old "Contact Support"/"Report a Problem" placeholder rows removed (the email card replaces them).
- `notification_preferences_screen.dart`: titled "Notifications" like the mockup; custom purple switches. In-app, Tickets and Account are locked ON (tap = explanation) because they are transactional; Email, Push, Resale, Promotions use `notificationSettings` as before. Still NOT persisted/enforced server-side (see Step 9 notes).
- `notifications_screen.dart`: grouped card with unread dots, "Read all", All/Tickets/Resale/System chips (Resale also holds local "ticket sold" items; System also holds general + promo). Tap behaviour, mark-read, pull-to-refresh, max width 820 kept.
- `resale_listing_screen.dart`: price text field replaced by slider + 4 quick prices (floor to ceiling, so it can't leave the 50-100% band); live fee/receive breakdown using `kResaleSellerFeeRate`; free tickets show a banner and can't be listed.
- `resale_confirmation_screen.dart` ("Your ticket is listed") and `ticket_sold_screen.dart` ("Your ticket sold"): new shared `FtResultScaffold`. Ticket sold now shows listing price, 5% fee and amount received; buttons are Done + View transactions (the old sampleTransactions lookup was dead code).
- `resale_checkout_screen.dart`: same PayMongo flow; restyled. Seller name is masked (H•••n). The GCash/Maya/Card pills only LIST methods; the real choice is made on the PayMongo page.
- `resale_market_screen.dart` + `market_listing_card.dart`, `my_listing_card.dart`, `resale_filter_chip.dart`: dark market. NEW: "Cancel listing" on My Listed Tickets (confirm dialog, then `ResaleRepository.cancelListing`). The round filter button next to the avatar is decorative (as before).
- NEW `lib/widgets/ft_resale_ui.dart`: `FtSurfaceCard`, `FtSectionLabel`, `FtSummaryRow`, `FtNote`, `FtResultScaffold`, `formatClosesAt`.
- Manual test: `flutter analyze`; Profile > Help & Support, Notifications settings; bell > Notifications (try each chip, Read all); My Tickets > list a ticket (move slider, tap quick prices, list) > confirmation > View My Listings > Cancel listing; buy a listing with a second account (checkout screen); tap a "ticket sold" notification; toggle Light mode on each.

## UI rework: light-mode alignment + payment method pills (2026-11-06), NOT compiled/run
- Light mode follows the same Ft* theme; four tweaks to match the light mockups: `FtSubpageScaffold`/`FtPageHeader` got `titleAtEnd` (right-aligned title, used by "List for resale"); pending status pill color (`ft_transaction_ui.dart`); notification switch off-track color; checkout pills.
- `resale_checkout_screen.dart`: GCash / Maya / Card pills are now SELECTABLE (default GCash, gradient when selected, disabled once payment starts). The app sends `paymentMethod` to the edge function.
- `supabase/functions/paymongo-checkout/index.ts`: reads `paymentMethod` (allowlist gcash/paymaya/card) and uses it as `payment_method_types` for ticket/resale checkout; missing/unknown value keeps all four methods; organizer plan checkout unchanged. MUST REDEPLOY: `supabase functions deploy paymongo-checkout`.
- Supersedes the earlier note that the pills only list methods.
- Open question: Transaction detail "Escrow: held until <date>" row needs `get_my_transactions()` + model changes + SQL run; not done.

## Organizer Dashboard blank/not loading fix (2026-11-06), NOT compiled/run
- Symptom: dashboard did not render; Flutter console showed "Cannot hit test a render box with no size" (a follow-up of an earlier layout error).
- Likely cause (from code reading, not reproduced): in `organizer-dashboard.dart` `_HeroRow`, the wide-screen (>=1000px) branch with NO featured event (no running/upcoming published event) returned a `Row(crossAxisAlignment: stretch)` directly inside the scaffold's `SingleChildScrollView` (unbounded height), which cannot lay out.
- Fix: that branch is now wrapped in `SizedBox(height: 170)`; the revenue card and stat tiles are children of that Row. Nothing else changed.
- Manual check: hot restart, open Organizer Dashboard at >=1000px width with (a) no events or only past events, (b) one running/upcoming published event, and at phone width. If the error remains, paste the FIRST red exception (not "Another exception was thrown").

## Multi-day day-pass wording on Create Event (2026-11-06), NOT compiled/run
- Backend already does one-ticket-per-day: `create_event_with_days` makes a parent + one child event per day, copies every tier to each day, enforces plan `max_multiday_days` and `max_tickets_per_day` server-side; `scan_ticket` accepts a day ticket only on its date. No SQL change made.
- `organizer-create-event.dart` only (UI): multi-day shows a summary box (day count + date range, "one ticket and QR per day, valid only on that day", tiers repeat on every day, live per-day and total capacity); tier quantity label becomes "Qty per day" for multi-day. Plan-limit errors still come from the server (client has no plan limits).
- NOT done (needs decisions): per-day pricing/tiers, skipping days, "buy all days" picker (eventgoer side), cancelling a single day, "valid for <date> only" scanner message, Escrow release date per day.
- Manual check: Create Event > Multi-Day, pick Nov 28 and Dec 6: box shows 9 days and capacity updates while typing quantities; Single-Day unchanged ("Quantity"); a 9-day run on a plan with a lower day limit shows the server's "Your plan allows multi-day events up to N days."

## Event types: Single-Day / Multi-Day per-day tickets / Multi-Day one pass (2026-11-06), NOT compiled/run
Decision (user): Single-Day = 1 day. Multi-Day "Ticket per day" = same show on several days, one ticket per account per day, separate pool per day (cinema style; existing behavior). Multi-Day "One pass for all days" = ONE ticket valid on every day, QR accepted once per day (convention style). Pass needs only 2+ days (the earlier "more than 3 days" was a typo); plan day/ticket caps apply to both multi-day modes.
Already present before this session (found in code, was NOT in this file): `events.ticket_scope` ('per_day'/'full_run') + `ticket_checkins` table, `create_event_with_days(..., p_ticket_scope)`, `scan_ticket` per-day check-in for full_run, `update_event_details` handling, `OrganizerEvent.fullRunPass`, `EventRepository.createEvent(fullRunPass:)`. A pass is ONE event row with its own tiers (quantity = total passes, checked against the plan's tickets-per-day cap).
Done this session (UI only, no SQL change):
- `organizer-create-event.dart`: Multi-Day shows a "Ticket Type" chooser (Ticket per day / One pass for all days), summary text and qty label ("Qty per day" vs "Total passes") follow it; `fullRunPass` is passed to both createEvent calls (draft + publish); switching to Single-Day resets it.
- `models/event.dart` (`EventSummary.isFullRunPass`), `public_event_repository.dart` (sets it from `ticket_scope`), `event_details_screen.dart` ("One pass for all days" notice above the tiers).
NOT done / unverified: Edit Event, My Events, Dashboard and ticket-wallet labels for passes (not read); scanner wording for a pass on a day it was already used (shows the generic already-used result); whether `organizer_event_functions.sql` / `scanner_functions.sql` were actually run in Supabase (re-run both; they are safe to re-run); a pass resold after entry on the same day is refused entry that day (by design of one check-in per date).
Manual test: run both SQL files; Create Event > Multi-Day > each Ticket Type; publish; as an eventgoer open the pass event (notice shows, buy once, second buy blocked); scan its QR on day 1 (valid), again same day (already used), on day 2 (valid); per-day event: day chips show, ticket only valid on its own day; `flutter analyze`.

## Showtimes / start times (2026-11-06), NOT compiled/run, NOT applied in Supabase
Decisions (user): one ticket per account per DAY across all showtimes; scanning is date-only with the showtime shown to staff; Single-Day and One-pass events get ONE optional start time; the plan's tickets-per-day cap counts all showtimes of a day together. Each showtime of a per-day event is its own child `events` row (own pool, tiers, cancel option), same `parent_event_id` + `event_start_date`, different `start_time`.
Found already in the project at the start of this session (earlier work, not recorded here before): `events.start_time`; `create_event_with_days(..., p_start_time, p_showtimes)` and the per-day cap in `update_event_details` (organizer_event_functions.sql); `event_slot_ids` + `ticket_slot_used` (checkout_guard.sql); slot-keyed lock in `_do_ticket_purchase` (purchase_functions.sql); "Tier · 7:00 PM" scan message (scanner_functions.sql); start_time-based resale cutoff in `list_ticket_for_resale`, `expire_resale_listings`, `get_resale_market` (resale_functions.sql / resale_purchase.sql); `lib/models/showtime.dart`; time-aware `EventSummary`, `Ticket`, `PublicEventRepository`, and Event Details (day -> showtime -> tier, limit counts a day's showings together).
Done this session:
- `supabase/resale_payment.sql`: `resale_checkout_quote` and `_do_resale_purchase` now close resale 24h before date + start_time (was date only) and `_do_resale_purchase` uses the same per-day lock key as `_do_ticket_purchase`.
- `lib/services/event_repository.dart`: `createEvent(startTime:, showtimes:)` sends `p_start_time` / `p_showtimes`; `_eventFromRow` fills `OrganizerEvent.startTime`; `fetchDays` orders by start_time too.
- `lib/models/organizer_event.dart`: added missing `import 'showtime.dart'` (`startTimeLabel` used `formatClockTime` without it, a compile error).
- `lib/screens/organizer/organizer-create-event.dart`: optional Start Time field (Single-Day, One pass); per-day multi-day gets a Showtimes section (add times once, they apply to every day, "Customize by day" to remove a time from one day); summary/qty label follow it ("Qty per showtime"); validation "Every day needs at least one showtime"; both createEvent calls pass startTime/showtimes.
- `lib/screens/organizer/organizer-cancel-event.dart`: single-day cancel list shows the showtime so two showings of one date are distinguishable.
NOT done / unverified: Edit Event cannot change times (update_event_details does not touch start_time) and does not show them; My Events/Dashboard rows show no times; the resale market's client-side limit check only matches the same event id (the server still blocks a second showing of that day); past-time showtime check is server-side only (uses Manila time); `buy_resale_listing` in resale_purchase.sql is superseded (dropped by resale_payment.sql) and still date-only; nothing compiled or run.
SQL to (re)run in the Supabase SQL Editor, in this order: `organizer_event_functions.sql`, `checkout_guard.sql`, `purchase_functions.sql`, `scanner_functions.sql`, `resale_functions.sql`, `resale_purchase.sql`, `resale_payment.sql` (all safe to re-run; resale_purchase.sql drops/recreates `get_resale_market`).
Manual test: `flutter analyze`; Create Event > Single-Day: set/clear a start time, publish, time shows on Event Details and ticket; Multi-Day > Ticket per day > add 3:00 PM and 7:00 PM, "Customize by day" to untick one time, publish; Event Details: pick day, then time, then tier; buy 3 PM, then try 7 PM the same day (blocked); a day with one showtime still works; scan a 7 PM ticket (message "General · 7:00 PM", accepted on its date); list a ticket for resale and confirm it closes 24h before the showtime; a day with every time removed is rejected; Cancel Event > cancel one showing only.

### Update 2026-11-06: non-consecutive dates (date + time showings), NOT compiled/run
SUPERSEDES the "same showtimes on every day + Customize by day" Create Event UI above. Decisions (user): per-day multi-day events are defined by a LIST of date + time showings (e.g. Nov 28-30 then Dec 3-5, no days in between); the plan's day cap counts DISTINCT dates, not the span; One-pass events keep the plain start/end date range; a per-day multi-day event needs showings on at least 2 different dates.
- `supabase/organizer_event_functions.sql` (`create_event_with_days`): with `p_showtimes`, the days are exactly the distinct listed dates (day_number 1..N over those), the parent's start/end are the earliest/latest date, the plan day cap uses the distinct-date count, fewer than 2 distinct dates is rejected. Without `p_showtimes` the old date-range behaviour is unchanged. MUST be re-run.
- `organizer-create-event.dart`: per-day mode hides the Start/End date pickers; new "Showings" section (Add showing = pick date, then time; grouped by date, chips removable); dates/time list drives start/end sent to `createEvent`; validation: at least 2 different dates, no showing in the past (device clock). Removed `_showTimes`, `_removedShowings`, `_runDays`, `_showtimesSection`.
- `public_event_repository.dart`: a multi-day event with gaps is labelled "6 days · Nov 28, 2026 – Dec 5, 2026".
NOT done: organizer lists (My Events/Dashboard) still show the plain span "11/28/2026 – 12/5/2026"; Edit Event still cannot change showings; the per-day cap check in `update_event_details` groups by date so it stays correct.
Manual test: re-run `organizer_event_functions.sql`; Create Event > Multi-Day > Ticket per day: add Nov 28/29/30 and Dec 3/4/5 (one with two times), publish; Event Details shows 6 day chips (no Dec 1-2) and the label "6 days · ..."; a plan with a 3-day cap rejects it with "up to 3 days"; only 1 date is rejected on the form; One pass still uses Start/End date; `flutter analyze`.

## Home feed redesign (2026-11-06), NOT compiled/run, NOT applied in Supabase
User decision: eventgoer Home is a Facebook-style feed (mockup "Dashboard feed"): every published event is a post card, newest first. Replaces the featured card + "Upcoming Events" list (which showed "No other upcoming events yet." whenever only one event existed: the first event was the featured card and the list skipped it). "..." menu left out for now (user).
- NEW `supabase/event_feed.sql` (MUST be run in the SQL Editor): `event_feed_organizers(uuid[])` SECURITY DEFINER returning event_id, organizer_name (organization_name, else full_name, else 'Organizer'), is_verified (verified + active). Needed because `users_select_own_or_admin` stops buyers reading organizer rows. Exposes nothing else.
- `models/event.dart`: `EventSummary.organizerName`, `isOrganizerVerified`, `postedAt` (events.created_at).
- `public_event_repository.dart`: calls the RPC for parent events (wrapped in try/catch; if the SQL is not applied the feed still loads, showing "Organizer" with no verified badge); fills `postedAt`. Catalogue order unchanged (start date) for other screens.
- `widgets/ft_dashboard_ui.dart`: NEW `FtEventPostCard` (organizer header with initial avatar + verified icon + "Posted 2h ago", 4:5 poster with accent placeholder, title, date, venue, caption = `description` with 3-line clamp and See more/See less only when longer, caption hidden when empty, footer "Tickets / Price TBA" | "Tickets / Free" | "From ₱X" + gradient "Get tickets") and `ftPostedAgo`. Old `FtFeaturedCard`, `FtUpcomingCard`, `FtTicketSection`, `FtWelcome` left in the file, now unused by Home.
- `screens/user/dashboard_screen.dart`: CORRECTED same day. User only wanted the CARD changed, not the layout. Home is back to the original layout (header, Welcome, search, My Tickets / Listed for resale counters, "Upcoming Events" + "View all", original start-date order, same ticket loading). UPDATE: the post cards now sit ONLY under "Upcoming Events" (no card between search and the counters). All events (first 5, `_upcomingLimit`; "View all" opens the rest) are listed there, including the first one, so the "No other upcoming events yet." message is gone (that was option C). The old featured card and its "Coming up / Happening now" pill are no longer used on Home.
Not verified: whether the `description` field is what organizers intend as a caption; price shows the cheapest tier via `formatPeso` ("₱122,222.00", mockup shows no decimals).
Manual test: run `supabase/event_feed.sql`; `flutter analyze`; open Home in dark + light: posts newest first, organizer name + badge, "Posted ..." age, banner or placeholder, See more only on long descriptions, Price TBA for an event with no tiers, Get tickets / poster / title open Event Details, search filters, pull-to-refresh, empty and search-no-match messages. Without the SQL: name shows "Organizer", no badge.

## Organizer: fix cancel error + Delete event (2026-11-06), NOT compiled/run, NOT applied in Supabase
Problem 1: cancelling an event showed "function public.notify_user(uuid, unknown, text, unknown) is not unique". Confirmed by the user's query in the Supabase SQL Editor: the database holds TWO overloads, `notify_user(uuid,text,text,notification_type,boolean)` (old, 5 args) and `notify_user(uuid,text,text,notification_type,boolean,boolean)` (current). No code change; the existing `supabase/fix_notify_user_overloads.sql` drops the old one. USER MUST RUN IT (not run by me). Unverified: why the 5-arg one reappeared (another SQL file may recreate it); re-run the overload query afterwards, expect only the 6-arg row.
Feature 2 (user chose option A): "Delete event" in My Events, only for Draft or Cancelled events.
- `supabase/organizer_event_functions.sql`: adds `events.deleted_at` + `delete_event(p_event_id)` (owner/admin, approved+active organizer, top-level event only, status draft/canceled only). No tickets ever -> hard delete of event, days, tiers. Canceled WITH tickets (or an FK blocks the delete) -> soft delete (`deleted_at` set, kept for revenue/refund/escrow consistency). Draft WITH tickets (e.g. admin-unpublished) -> refused ("Cancel it first"). MUST be re-run.
- `lib/services/event_repository.dart`: `deleteEvent` now calls the RPC (was a raw table delete; same signature); `refresh()` hides rows with `deleted_at` (filtered in Dart, so the app does not break if the column does not exist yet).
- `lib/screens/organizer/organizer-my-events.dart`: "Delete event" item in the ... menu (draft/cancelled only), approval check, confirmation dialog, snackbar result.
Not done / unverified: banner/document files in Storage are NOT removed (no owner delete policy on `event_documents`; direct SQL deletes from storage.objects are unsafe) so a hard delete leaves orphaned files; the monthly event-count usage is not decremented on delete (intentional, avoids bypassing plan limits); whether another screen already calls `deleteEvent` (no project-wide grep); old direct-delete RLS on `events` for organizers was not inspected; admin screens still list soft-deleted events (intended, audit).
Manual test: run `fix_notify_user_overloads.sql`, then `organizer_event_functions.sql`; cancel a test event (no more error); My Events > Cancelled filter > ... > Delete event (disappears, refresh keeps it gone; Analytics/Escrow totals unchanged if it had sales); create a draft > Delete (gone for good); a Published event shows no Delete item; `flutter analyze`.

### Exact next step (this task)
User: run `fix_notify_user_overloads.sql`, then `organizer_event_functions.sql` in the Supabase SQL Editor, `flutter analyze`, then test cancel + delete as above and report results.

## Eventgoer: banner pictures no longer cropped (2026-11-06), NOT compiled/run
Problem: the organizer's banner was cut in the goer app (home feed card forced a 4:5 box with `BoxFit.cover`; Event Details hero was a fixed 240-340px strip with `BoxFit.cover`).
- `lib/widgets/ft_dashboard_ui.dart` (`FtEventPostCard._poster`): picture now shows at full card width with its own height (`BoxFit.contain`), capped at 1.25x width (the old 4:5); a taller picture is shown whole with dark side bars. Placeholder (no banner / loading / error) is still 4:5.
- `lib/screens/user/event_details_screen.dart` (`_EventBanner`): same approach for the hero (cap 1.25x width); placeholder keeps the old height. Back-button shade kept.
NOT changed (still cropped thumbnails by design, not read where noted): Upcoming list thumbnail `FtUpcomingCard` (70x70), the old `FtFeaturedCard` background (unused on Home), `featured_event_card.dart`, `all_events_screen.dart` (not read), organizer-side previews, ticket wallet. The card height now varies per event, so posts in the feed have different heights.
Manual test: `flutter analyze`; upload a wide (16:9), a square and a tall portrait banner; Home feed and Event Details show each whole, no cut; dark + light; event without banner shows the placeholder; slow load shows placeholder, then the picture.

## Eventgoer: UI slightly smaller (2026-11-06), NOT compiled/run
- Feed card label "Starting at" -> "Starts at" (`ft_dashboard_ui.dart`).
- `lib/main.dart` (`MaterialApp.builder`): on the phone app (not web) text is now drawn 8% smaller (`_phoneTextShrink = 0.92`; user font size still respected, clamped 0.85-1.2 before the shrink). Web (organizer/admin) unchanged. Only TEXT scales: paddings, icons, buttons, card sizes and the many hardcoded `fontSize` values are untouched. Set the constant to 1.0 to undo. A nonlinear Android font scale is treated as linear.
- NOT done: spacing/icon/button size reduction; per-screen font changes.
Manual test: `flutter analyze`; open the phone app (Home, Event Details, Tickets, Profile): text a bit smaller, nothing clipped or overflowing, large system font size still caps sensibly.

## Eventgoer Home: pinned header (2026-11-06), NOT compiled/run
- `lib/screens/user/dashboard_screen.dart`: the logo + bell + profile row (`FtDashboardHeader`) moved out of the scroll view into a Column above it, so it stays at the top while the page scrolls (content scrolls in an `Expanded` below it; pull-to-refresh still works on the scrolling part). Spacing kept (header bottom 10 + list top 12 = old 22 gap). Home tab only; other tabs/screens untouched.
Manual test: `flutter analyze`; Home: scroll the feed (header stays), pull to refresh, tap bell and profile, check dark + light and a phone with a notch.

## Organizer web: text 10% smaller (2026-11-06), NOT compiled/run
- `lib/screens/organizer/organizer-scaffold.dart`: `OrganizerScaffold` now wraps its Scaffold in a `MediaQuery` that multiplies the text scale by `organizerTextShrink = 0.9` (public const, 1.0 = off; the browser/user font setting is still applied first). Affects every page built on `OrganizerScaffold` (Dashboard, My Events, Analytics, Escrow, Profile, Subscription, Settings, Help, Create/Edit/Cancel Event...) incl. top bar and pill nav.
- NOT affected: admin pages (own shell), pages without the scaffold (organizer login/register/splash/landing/document upload/plan chooser), and overlays that sit above the page (dialogs, bell/profile dropdowns, snackbars) which keep full-size text. Only text scales: paddings, icons, cards, logo, bar heights unchanged.
Manual test: `flutter analyze`; Chrome at 100% zoom on a large screen: each organizer page smaller text, nothing clipped (pill nav, stat cards, tables); compare a dialog/dropdown (full size).

## Organizer: poster thumbnail not cropped (2026-11-06), NOT compiled/run
- `lib/widgets/organizer_event_widgets.dart` (`OrganizerEventAvatar`): banner now `BoxFit.contain` on a neutral (`progressTrack`) background instead of `cover`, so the whole poster shows in the small tile (My Events cards and anywhere else the avatar is used; tile size unchanged, so a wide/tall poster leaves bars). Initials fallback unchanged.
- NOT checked/changed: banner preview inside Create Event / Edit Event (files not read), Dashboard featured card, Analytics.
Manual test: `flutter analyze`; My Events with a wide, a square and a tall poster: each fully visible in the tile.

## Organizer Dashboard: event card posters not cropped (2026-11-06), NOT compiled/run
Correction: the user meant the Dashboard's "My Events" cards, not the My Events page (the avatar change above stays; harmless).
- `lib/screens/organizer/organizer-dashboard.dart` (`_EventCard`): the 110px banner strip (`BoxFit.cover`) is now the poster at full card width with its own height (`BoxFit.contain`, capped at 240px, dark bars at the sides for a tall poster). No banner / loading / error still shows the 110px purple strip. Status chip stays on top-left. Cards in a row can now have different heights.
- NOT changed: the big featured card (it has no poster, only the purple gradient).
Manual test: `flutter analyze`; Organizer Dashboard with a wide, square and tall poster: each fully visible; event without poster shows the purple strip.

### Exact next step (this task)
User: run `fix_notify_user_overloads.sql`, then `organizer_event_functions.sql` in the Supabase SQL Editor, `flutter analyze`, then test cancel + delete + banner display (goer + organizer dashboard) + the text sizes and report results.

## Organizer Create Event: layout/UI polish (2026-11-06), NOT compiled/run
UI-only change in `lib/screens/organizer/organizer-create-event.dart`. Validation, `EventRepository` calls, access check, uploads, showings and day-pass logic untouched. No SQL, no new dependencies.
- Sections (left column): Basic Information (name, description) -> Date & Time (duration, ticket type, dates, start time / showings, summary) -> Venue (own card, same place for Single-Day and Multi-Day; was beside the date for Single-Day only) -> Ticket Tiers & Prices. Right column: Event Banner, Supporting Documents. Cards got an icon tile, subtitle and divider (`_card` has new optional `icon`/`subtitle`).
- New helpers: `_SegOption`, `_segmented<T>` (replaces the 4 hand-styled ChoiceChips for duration and ticket type), `_tierCard` (numbered tier card: name/price/qty in a row >=520px, stacked below, remove button, `ObjectKey` per tier), `_errorBanner` (styled form error), `_actionBar` (bordered bar for Cancel / Save as Draft / Publish).
- Single-Day: Start Time now sits beside the Date (was a separate row below); One-pass multi-day keeps Start Time under the dates. Day-pass summary box got an info icon.
- Behavior notes: removing a tier no longer reuses the removed card's dropdown state (keyed per tier); remove button is also disabled while submitting; tier delete icon is greyed when only one tier is left.
- Not changed: `OrganizerScaffold`, `organizer-form-widgets.dart`, Edit Event screen (still the old layout, so the two screens now look different).
Manual test: `flutter analyze`; Create Event wide (>=1000px), ~800px and phone width, light + dark: switch Single-Day/Multi-Day and both ticket types (selector highlight, summary, Start Time placement), add/remove tiers (3 tiers, remove the middle one, values stay correct), trigger validation (empty form -> per-field errors + red banner above the buttons), venue search dropdown opens fully over the cards, banner upload, add/remove documents, Save as Draft, Publish.
Exact next step: user runs `flutter analyze`, checks the screen, and tells me what to adjust (spacing, order, Edit Event to match).

### Update 2026-11-06 (second pass): rebuilt in the Dashboard style, NOT compiled/run
User feedback on the first pass: spacing/alignment off, styling dated; wanted the Organizer Dashboard look (pill/gradient). Root cause: the screen still used legacy `AppTextStyles` (Poppins), `AppTextField` (10px radius) and pill-shaped `OutlineButtonWidget`, while the Dashboard uses `orgText` (Plus Jakarta Sans), `OrganizerCard`, 14px fields and the gradient buttons from `lib/widgets/organizer_ui.dart`.
SUPERSEDES the helper names above where they differ. Changed files:
- `lib/screens/organizer/organizer-create-event.dart`: REWRITTEN (all logic functions copied unchanged: validation, `_saveDraft`, `_publishEvent`, uploads, showings, day counts). Now: Dashboard-style header (36px title, subtitle, Cancel / Save as Draft / Publish Event top-right and again at the bottom), `OrganizerCard` sections (radius 24, tinted icon tile, 18px bold title, subtitle), 24px gap between cards, 20px between fields, segmented selectors with a gradient selected pill, 14px-radius fields via local `_field`/`_dec`, `OrganizerFieldLabel` labels, tier cards (radius 20, numbered, 3 fields in a row >=520px), `OrganizerUploadBox` for banner and documents, banner preview shown whole (`BoxFit.contain`, 190px), styled error banner shown under the header and above the bottom buttons. No longer imports `app_colors.dart`.
- `lib/screens/organizer/organizer-form-widgets.dart`: venue + tier dropdowns, `FieldWarning` switched to `orgText`, 14px radius, 18px vertical padding, `p.danger` instead of `AppColors.dangerRed`; import `app_colors.dart` replaced by `organizer_ui.dart`. SHARED with Edit Event, so Edit Event's venue/tier fields and warnings now look like this too (its other fields still use `AppTextField`, so it is now slightly mixed until Edit Event is restyled).
- Safety backup of the pre-rewrite file: `lib/screens/organizer/organizer-create-event.dart.bak` (not compiled; DELETE by hand once the new screen is confirmed, or rename back to restore the first-pass version).
Unverified: compile (generic `_segmented<T>`, `const _SegOption` lists), the exact heights of dropdown vs text fields side by side in a tier row (all use isDense + 18px padding), venue dropdown overlay over the new cards, mobile widths.
Manual test: `flutter analyze`; Create Event at >=1000px, ~800px, phone width, light + dark: header + buttons, both segmented selectors, Single-Day (Date + Start Time side by side), Multi-Day both ticket types and showings, tiers (add 3, remove middle), empty submit (field errors + red banner under header and above bottom buttons), venue search dropdown, banner and document upload, Save as Draft, Publish; also open Edit Event to check the shared venue/tier fields still look right.
Exact next step: user runs `flutter analyze`, checks the screen, then tells me what to adjust; afterwards restyle Edit Event the same way.
