import 'package:flutter/material.dart';

import '../../models/organizer.dart';
import 'organizer-dashboard.dart';
import 'organizer-document-upload.dart';
import 'organizer-subscription-plan.dart';
import 'organizer-verification-pending.dart';

/// The screen an organizer belongs on right now, based on their account.
///
/// Mirrors the routing in `organizer-login.dart` so a browser refresh puts a
/// still-signed-in organizer back where a fresh login would:
///  - documents missing  -> upload screen
///  - not yet verified   -> verification pending
///  - verified, no plan  -> subscription plan picker
///  - verified, has plan -> dashboard
Widget organizerLandingFor(OrganizerAccount account) {
  if (!account.hasSubmittedDocuments) {
    return OrganizerDocumentUploadScreen(account: account);
  }
  if (account.idVerificationStatus != 'verified') {
    return const OrganizerVerificationPendingScreen();
  }
  if (account.subscriptionPlan == null) {
    return const OrganizerSubscriptionPlanScreen();
  }
  return const OrganizerDashboardScreen();
}
