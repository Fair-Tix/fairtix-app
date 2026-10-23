import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizer_session.dart';

/// Thrown when generating an organizer report fails (including when the
/// organizer's plan does not allow exporting).
class OrganizerReportException implements Exception {
  final String message;
  const OrganizerReportException(this.message);
}

/// The organizer's own revenue report, for CSV / PDF export.
///
/// Exporting is a per-plan feature: the admin switches "Allow report export"
/// on or off for each plan in Platform Settings (`subscription_plans.can_export`).
/// The rule is enforced twice:
///  - here / in the UI, so organizers on a plan without export see a locked
///    button with an upgrade prompt instead of an error;
///  - on the server, in `organizer_revenue_report` (via
///    `organizer_can_export()`, supabase/organizer_report_functions.sql),
///    which raises for any plan without export, so the data cannot be pulled
///    by calling the API directly.
class OrganizerReportService {
  OrganizerReportService._();
  static final OrganizerReportService instance = OrganizerReportService._();

  /// Whether the signed-in organizer's current plan allows exporting. Comes
  /// from the plan itself (loaded at login and after each purchase), never
  /// from the plan's name, so renaming or adding plans cannot break it.
  bool get canExport =>
      OrganizerSession.instance.account?.subscriptionCanExport ?? false;

  /// One row per event (first row = header). Money columns are labelled PHP
  /// so the same rows print cleanly in the PDF, whose built-in font has no
  /// peso sign.
  Future<List<List<Object?>>> revenueReportRows({DateTime? from, DateTime? to}) async {
    if (!canExport) {
      throw const OrganizerReportException(
        'Exporting reports is not included in your current plan.',
      );
    }
    try {
      final rows =
          await Supabase.instance.client.rpc(
                'organizer_revenue_report',
                params: {
                  'p_from': from?.toUtc().toIso8601String(),
                  'p_to': to?.toUtc().toIso8601String(),
                },
              )
              as List;
      return [
        const [
          'Event',
          'Status',
          'Event Date',
          'Tickets Sold',
          'Gross Revenue (PHP)',
          'Platform Fees (PHP)',
          'Net Payout (PHP)',
        ],
        for (final row in rows.cast<Map<String, dynamic>>())
          [
            row['event_title'],
            row['event_status'],
            row['event_date'],
            row['tickets_sold'],
            row['gross_revenue'],
            row['platform_fees'],
            row['net_payout'],
          ],
      ];
    } on PostgrestException catch (e) {
      // PGRST202 = function missing: the SQL file has not been run yet.
      if (e.code == 'PGRST202') {
        throw const OrganizerReportException(
          'Reports are not set up yet: run supabase/organizer_report_functions.sql '
          'in the Supabase SQL Editor first.',
        );
      }
      throw OrganizerReportException(e.message);
    }
  }
}
