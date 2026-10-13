import 'package:supabase_flutter/supabase_flutter.dart';

import 'csv_export.dart' show toCsv;

/// Thrown when generating a report fails.
class AdminReportException implements Exception {
  final String message;
  const AdminReportException(this.message);
}

/// Builds the admin reports as CSV text. Saving the file is
/// `saveCsvFile` in csv_export.dart.
///
/// Transactions and revenue come from the `admin_transaction_report` /
/// `admin_revenue_report` Postgres functions (supabase/report_functions.sql,
/// admin-only); refunds are read straight from `public.refunds`, which
/// admins can read via RLS.
///
/// Every method takes an optional date range: [from] inclusive, [to]
/// exclusive, either may be null for no limit on that side.
class AdminReportService {
  AdminReportService._();
  static final AdminReportService instance = AdminReportService._();

  Future<String> transactionReportCsv({DateTime? from, DateTime? to}) async {
    final rows = await _rpc('admin_transaction_report', from, to);
    return toCsv([
      const [
        'Transaction ID',
        'Date',
        'Type',
        'Status',
        'Event',
        'Tier',
        'Buyer',
        'Buyer Email',
        'Seller',
        'Amount (PHP)',
        'Platform Fee (PHP)',
        'Escrow',
      ],
      for (final r in rows)
        [
          r['tx_id'],
          r['tx_date'],
          r['tx_type'],
          r['tx_status'],
          _safe(r['event_title']),
          _safe(r['tier_name']),
          _safe(r['buyer_name']),
          _safe(r['buyer_email']),
          _safe(r['seller_name']),
          r['amount'],
          r['platform_fee'],
          r['escrow'],
        ],
    ]);
  }

  /// One row per event + organizer + fee rate, so the Plan and Fee Rate
  /// columns show the 8% / 9% / 10% split. Refunded sales are excluded.
  Future<String> revenueReportCsv({DateTime? from, DateTime? to}) async {
    final rows = await _rpc('admin_revenue_report', from, to);
    return toCsv([
      const [
        'Event',
        'Organizer',
        'Plan',
        'Fee Rate',
        'Tickets Sold',
        'Gross Revenue (PHP)',
        'Platform Fees (PHP)',
        'Net Payout (PHP)',
      ],
      for (final r in rows)
        [
          _safe(r['event_title']),
          _safe(r['organizer_name']),
          r['plan_name'],
          '${((r['fee_rate'] as num) * 100).round()}%',
          r['tickets_sold'],
          r['gross_revenue'],
          r['platform_fees'],
          r['net_payout'],
        ],
    ]);
  }

  Future<String> refundReportCsv({DateTime? from, DateTime? to}) async {
    try {
      var query = Supabase.instance.client.from('refunds').select('''
            refund_id, amount, reason, status, created_at, processed_at,
            users(full_name, email),
            events(title)
          ''');
      if (from != null) {
        query = query.gte('created_at', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lt('created_at', to.toUtc().toIso8601String());
      }
      final rows = await query.order('created_at', ascending: false) as List;
      return toCsv([
        const [
          'Refund ID',
          'Requested',
          'Event',
          'Buyer',
          'Buyer Email',
          'Amount (PHP)',
          'Reason',
          'Status',
          'Processed',
        ],
        for (final row in rows)
          () {
            final r = row as Map<String, dynamic>;
            final buyer = r['users'] as Map<String, dynamic>?;
            final event = r['events'] as Map<String, dynamic>?;
            return [
              r['refund_id'],
              r['created_at'],
              _safe(event?['title']),
              _safe(buyer?['full_name']),
              _safe(buyer?['email']),
              r['amount'],
              _safe(r['reason']),
              r['status'],
              r['processed_at'],
            ];
          }(),
      ]);
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _rpc(
    String function,
    DateTime? from,
    DateTime? to,
  ) async {
    try {
      final rows =
          await Supabase.instance.client.rpc(
                function,
                params: {
                  'p_from': from?.toUtc().toIso8601String(),
                  'p_to': to?.toUtc().toIso8601String(),
                },
              )
              as List;
      return rows.cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw AdminReportException('Could not generate the report: ${e.message}');
    }
  }

  /// Text that starts with = + - @ gets a leading apostrophe, so Excel or
  /// Sheets can't run a user-supplied name or event title as a formula.
  Object? _safe(Object? value) {
    if (value is String && value.isNotEmpty && '=+-@'.contains(value[0])) {
      return "'$value";
    }
    return value;
  }
}
