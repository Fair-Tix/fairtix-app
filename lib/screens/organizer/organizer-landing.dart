import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import 'organizer-dashboard.dart';
import 'organizer-document-upload.dart';
import 'organizer-subscription-plan.dart';

/// The screen an organizer belongs on right now, based on their account.
///
/// Mirrors the routing in `organizer-login.dart` so a browser refresh puts a
/// still-signed-in organizer back where a fresh login would:
///  - documents missing          -> upload screen (finish the application)
///  - not yet approved           -> dashboard, browse-only (features locked)
///  - approved, never subscribed -> subscription plan picker
///  - approved, plan expired     -> dashboard (subscription features locked
///                                  until they renew; never logged out)
///  - approved, active plan      -> dashboard
///
/// The dashboard shows a banner explaining anything that is locked and why.
Widget organizerLandingFor(OrganizerAccount account) {
  if (!account.hasSubmittedDocuments) {
    return OrganizerDocumentUploadScreen(account: account);
  }
  if (!account.isApproved) {
    return const OrganizerDashboardScreen();
  }
  if (account.subscriptionPlan == null && !account.subscriptionExpired) {
    return const OrganizerSubscriptionPlanScreen();
  }
  return const OrganizerDashboardScreen();
}
