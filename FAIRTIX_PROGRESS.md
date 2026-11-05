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
