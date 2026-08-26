import 'package:flutter/material.dart';

import 'tab_index_notifier.dart';

/// Switches the persistent [MainShell]'s active tab from anywhere else
/// in the app (e.g. "Back to My Tickets" after listing a ticket for
/// resale).
///
/// This assumes [MainShell] is already on the navigator stack as the
/// first route — true for everywhere this is called from, since the
/// only way into the main app (login, registration, etc.) pushes
/// [MainShell] with `pushAndRemoveUntil`. It pops back down to that
/// shell (discarding whatever was pushed on top, e.g. Ticket Detail or
/// Checkout) and flips [mainShellTabIndex], which the shell listens to
/// to slide its `PageView` to the target tab. The shell's
/// `Scaffold.bottomNavigationBar` never rebuilds or re-navigates — only
/// the page content slides — so the bottom nav bar stays fixed in place
/// throughout.
void navigateToTab(BuildContext context, int index) {
  mainShellTabIndex.value = index;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
