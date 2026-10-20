import 'package:fairtix_app/models/app_user.dart';
import 'package:fairtix_app/models/organizer.dart';
import 'package:fairtix_app/services/access_control.dart';
import 'package:flutter_test/flutter_test.dart';

OrganizerAccount _organizer({
  String status = 'verified',
  String? plan,
  DateTime? renewsAt,
  DateTime? expiredAt,
}) {
  return OrganizerAccount(
    id: 'org-1',
    fullName: 'Test Organizer',
    email: 'org@example.com',
    organizationName: 'Test Org',
    idVerificationStatus: status,
    subscriptionPlan: plan,
    subscriptionRenewsAt: renewsAt,
    subscriptionExpiredAt: expiredAt,
  );
}

AppUser _buyer({
  String status = 'verified',
  String? idDocumentUrl = 'path/id.jpg',
}) {
  return AppUser(
    fullName: 'Test Buyer',
    username: 'buyer',
    email: 'buyer@example.com',
    idType: 'National ID',
    isVerified: status == 'verified',
    idVerificationStatus: status,
    idDocumentUrl: idDocumentUrl,
  );
}

void main() {
  final future = DateTime.now().toUtc().add(const Duration(days: 30));
  final past = DateTime.now().toUtc().subtract(const Duration(days: 3));

  group('eventgoer lock', () {
    test('verified buyers are never locked', () {
      expect(buyerLockMessage(_buyer()), isNull);
    });

    test('pending buyers are told they are waiting for approval', () {
      final message = buyerLockMessage(_buyer(status: 'pending'));
      expect(message, contains('waiting for admin approval'));
      expect(message, contains('keep browsing'));
    });

    test('buyers with no ID yet are told to submit one', () {
      final message =
          buyerLockMessage(_buyer(status: 'pending', idDocumentUrl: null));
      expect(message, contains('locked'));
      expect(buyerNeedsIdSubmission(_buyer(status: 'pending', idDocumentUrl: null)),
          isTrue);
    });

    test('rejected buyers are told to resubmit', () {
      final message = buyerLockMessage(_buyer(status: 'rejected'));
      expect(message, contains('rejected'));
      expect(buyerNeedsIdSubmission(_buyer(status: 'rejected')), isTrue);
    });

    test('no account at all is locked, not an error', () {
      expect(buyerLockMessage(null), isNotNull);
    });
  });

  group('organizer account state', () {
    test('approved with a current plan has an active subscription', () {
      final account = _organizer(plan: 'Basic', renewsAt: future);
      expect(account.isApproved, isTrue);
      expect(account.hasActiveSubscription, isTrue);
      expect(account.subscriptionExpired, isFalse);
    });

    test('a plan whose end date has passed counts as expired', () {
      final account = _organizer(plan: 'Basic', renewsAt: past);
      expect(account.hasActiveSubscription, isFalse);
      expect(account.subscriptionExpired, isTrue);
    });

    test('no plan but a recorded expiry counts as expired', () {
      final account = _organizer(expiredAt: past);
      expect(account.hasActiveSubscription, isFalse);
      expect(account.subscriptionExpired, isTrue);
    });

    test('never subscribed is neither active nor expired', () {
      final account = _organizer();
      expect(account.hasActiveSubscription, isFalse);
      expect(account.subscriptionExpired, isFalse);
    });

    test('pending organizers are not approved', () {
      expect(_organizer(status: 'pending').isApproved, isFalse);
    });
  });

  group('organizer lock messages', () {
    test('unapproved organizers are locked from every feature', () {
      final account = _organizer(status: 'pending');
      for (final requirement in OrganizerRequirement.values) {
        expect(
          organizerLockMessage(account, requirement),
          contains('waiting for admin approval'),
        );
      }
    });

    test('rejected organizers are told to contact support', () {
      final message = organizerLockMessage(
        _organizer(status: 'rejected'),
        OrganizerRequirement.approval,
      );
      expect(message, contains('rejected'));
    });

    test('an expired subscription locks only subscription features', () {
      final account = _organizer(plan: 'Basic', renewsAt: past);
      expect(
        organizerLockMessage(account, OrganizerRequirement.approval),
        isNull,
      );
      final message = organizerLockMessage(
        account,
        OrganizerRequirement.subscription,
      );
      expect(message, contains('expired'));
      expect(message, contains('renew'));
    });

    test('approved organizers with no plan are asked to choose one', () {
      final message = organizerLockMessage(
        _organizer(),
        OrganizerRequirement.subscription,
      );
      expect(message, contains('Choose a plan'));
    });

    test('an approved organizer with a current plan is unlocked', () {
      final account = _organizer(plan: 'Basic', renewsAt: future);
      for (final requirement in OrganizerRequirement.values) {
        expect(organizerLockMessage(account, requirement), isNull);
      }
    });
  });
}
