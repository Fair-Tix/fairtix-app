import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/organizer.dart';
import '../screens/organizer/organizer-subscription-plan.dart';
import '../screens/user/identity_verification_screen.dart';
import 'organizer_auth_service.dart';
import 'organizer_session.dart';
import 'user_auth_service.dart';
import 'user_session.dart';

/// What an organizer feature needs before it unlocks.
///  - [approval]: an admin has approved the organizer account.
///  - [subscription]: approval AND a current (not expired) subscription.
enum OrganizerRequirement { approval, subscription }

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Why [user] can't buy tickets, resell, or use other restricted eventgoer
/// features, or null when everything is unlocked. Browsing is never locked.
String? buyerLockMessage(AppUser? user) {
  if (user != null && user.isVerified) return null;
  if (user != null && user.idVerificationStatus == 'rejected') {
    return 'Your ID verification was rejected, so buying tickets and reselling are locked. '
        'Please resubmit your ID and selfie so an admin can approve your account.';
  }
  if (user == null || user.idDocumentUrl == null) {
    return 'Buying tickets and reselling are locked until an admin approves your account. '
        'Submit your ID and a selfie to start verification. You can keep browsing events in the meantime.';
  }
  return 'Your account is waiting for admin approval (usually 1\u20132 business days). '
      'Buying tickets and reselling unlock as soon as it is approved. You can keep browsing events in the meantime.';
}

/// True when the eventgoer still has to submit (or resubmit) their ID.
bool buyerNeedsIdSubmission(AppUser? user) =>
    user == null ||
    user.idDocumentUrl == null ||
    user.idVerificationStatus == 'rejected';

/// Why an organizer feature is locked, or null when it is available.
String? organizerLockMessage(
  OrganizerAccount? account,
  OrganizerRequirement requirement,
) {
  if (account == null || !account.isApproved) {
    if (account != null && account.idVerificationStatus == 'rejected') {
      return 'Your organizer application was rejected, so this feature is locked. '
          'Please contact FairTix support. You can still browse events.';
    }
    return 'Your organizer application is waiting for admin approval (usually 24\u201348 hours). '
        'This feature unlocks once you are approved. You can keep browsing events in the meantime.';
  }
  if (requirement == OrganizerRequirement.subscription &&
      !account.hasActiveSubscription) {
    final expiredAt = account.subscriptionExpiredAt;
    if (account.subscriptionExpired) {
      return 'Your subscription expired${expiredAt != null ? ' on ${_fmt(expiredAt)}' : ''}. '
          'Creating and editing events, scanner sessions, announcements and exports are locked until you renew. '
          'You can still view your events and past sales.';
    }
    return 'You don\u2019t have an active subscription yet. Choose a plan to create events, '
        'start scanner sessions and send announcements.';
  }
  return null;
}

/// Checks (against the server, so a freshly approved account unlocks without
/// logging out) that the signed-in eventgoer may buy / resell. Returns true
/// when allowed; otherwise explains why in a dialog and returns false.
Future<bool> ensureBuyerApproved(BuildContext context) async {
  var user = UserSession.instance.account;
  if (user != null && user.isVerified) return true;
  try {
    user = await UserAuthService.instance.refreshAccount() ?? user;
  } catch (_) {}
  if (user != null && user.isVerified) return true;
  if (!context.mounted) return false;

  final message = buyerLockMessage(user)!;
  final needsId = buyerNeedsIdSubmission(user);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('This feature is locked')),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        if (needsId)
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IdentityVerificationScreen(),
                ),
              );
            },
            child: Text(user?.idVerificationStatus == 'rejected'
                ? 'Resubmit ID'
                : 'Verify now'),
          ),
      ],
    ),
  );
  return false;
}

/// Checks (against the server, so a freshly approved or renewed account
/// unlocks without logging out) that the signed-in organizer may use a
/// feature needing [requirement]. Returns true when allowed; otherwise
/// explains why in a dialog, with a button to renew or choose a plan when
/// that is what's missing, and returns false.
///
/// Never signs the organizer out: an expired subscription only locks the
/// subscription features, never login or viewing.
Future<bool> ensureOrganizerAccess(
  BuildContext context,
  OrganizerRequirement requirement,
) async {
  var account = OrganizerSession.instance.account;
  if (organizerLockMessage(account, requirement) == null) return true;
  try {
    account = await OrganizerAuthService.instance.refreshAccount() ?? account;
  } catch (_) {}
  final message = organizerLockMessage(account, requirement);
  if (message == null) return true;
  if (!context.mounted) return false;

  final canFixWithPlan = account != null &&
      account.isApproved &&
      requirement == OrganizerRequirement.subscription;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('This feature is locked')),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        if (canFixWithPlan)
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OrganizerSubscriptionPlanScreen(),
                ),
              );
            },
            child: Text(account!.subscriptionExpired ? 'Renew plan' : 'Choose a plan'),
          ),
      ],
    ),
  );
  return false;
}

/// Convenience for screens that only need the organizer's current session.
OrganizerAccount? get currentOrganizer => OrganizerSession.instance.account;
