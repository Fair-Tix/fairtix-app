import 'package:flutter_test/flutter_test.dart';
import 'package:fairtix_app/screens/admin/admin-organizer-applications.dart';

void main() {
  group('AdminOrganizerApplicationsScreen status helpers', () {
    test('maps Supabase verification statuses to admin labels', () {
      expect(AdminOrganizerApplicationsScreen.statusLabelFor('pending'), 'Pending');
      expect(AdminOrganizerApplicationsScreen.statusLabelFor('verified'), 'Approved');
      expect(AdminOrganizerApplicationsScreen.statusLabelFor('rejected'), 'Rejected');
      expect(AdminOrganizerApplicationsScreen.statusLabelFor(null), 'Pending');
    });

    test('matches the selected admin filter against application status', () {
      final pendingApplication = {'id_verification_status': 'pending'};
      final approvedApplication = {'id_verification_status': 'verified'};
      final rejectedApplication = {'id_verification_status': 'rejected'};

      expect(AdminOrganizerApplicationsScreen.matchesFilter(pendingApplication, 0), isTrue);
      expect(AdminOrganizerApplicationsScreen.matchesFilter(pendingApplication, 1), isTrue);
      expect(AdminOrganizerApplicationsScreen.matchesFilter(approvedApplication, 2), isTrue);
      expect(AdminOrganizerApplicationsScreen.matchesFilter(rejectedApplication, 3), isTrue);
      expect(AdminOrganizerApplicationsScreen.matchesFilter(approvedApplication, 1), isFalse);
      expect(AdminOrganizerApplicationsScreen.matchesFilter(rejectedApplication, 2), isFalse);
    });

    test('detects organizer applications even when the stored role metadata is stale', () {
      final organizerLikeApplication = {
        'role': 'buyer',
        'organization_name': 'Campus Events Co.',
        'venue_proof_url': 'organizer_docs/test.pdf',
        'event_permit_url': null,
      };
      final regularBuyer = {
        'role': 'buyer',
        'organization_name': null,
        'venue_proof_url': null,
        'event_permit_url': null,
      };

      expect(
        AdminOrganizerApplicationsScreen.isOrganizerApplicationCandidate(organizerLikeApplication),
        isTrue,
      );
      expect(
        AdminOrganizerApplicationsScreen.isOrganizerApplicationCandidate(regularBuyer),
        isFalse,
      );
    });
  });
}
