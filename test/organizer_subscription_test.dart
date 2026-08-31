import 'package:flutter_test/flutter_test.dart';
import 'package:fairtix_app/models/organizer_event.dart';
import 'package:fairtix_app/services/organizer_auth_service.dart';

void main() {
  test('maps organizer plan fees to the correct plan names', () {
    expect(OrganizerAuthService.planNameFromMonthlyFee(299), 'Basic');
    expect(OrganizerAuthService.planNameFromMonthlyFee(699), 'Standard');
    expect(OrganizerAuthService.planNameFromMonthlyFee(1499), 'Premium');
    expect(OrganizerAuthService.planNameFromMonthlyFee(999), isNull);
  });

  test('formats organizer event dates for single-day and multi-day events', () {
    expect(
      OrganizerEvent.formatDateRange('04/15/2026', '04/15/2026', false),
      'Apr 15, 2026',
    );
    expect(
      OrganizerEvent.formatDateRange('04/15/2026', '04/17/2026', true),
      'Apr 15-17, 2026',
    );
  });
}
