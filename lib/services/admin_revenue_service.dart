import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when loading platform revenue fails.
class AdminRevenueException implements Exception {
  final String message;
  const AdminRevenueException(this.message);
}

/// Platform fee totals for one organizer plan.
class PlanRevenue {
  const PlanRevenue({
    required this.plan,
    required this.rate,
    required this.tickets,
    required this.gross,
    required this.fees,
    required this.net,
  });

  final String plan;

  /// Fee rate as a fraction, e.g. 0.08 for 8%.
  final double rate;
  final int tickets;
  final double gross;
  final double fees;
  final double net;

  String get rateLabel => '${(rate * 100).round()}%';
}

/// Admin-only platform revenue, backed by the `admin_revenue_by_plan()`
/// Postgres function (supabase/revenue_functions.sql), which sums the rows
/// the purchase trigger writes to `public.organizer_fees`.
///
/// Fee rate by plan (matches organizer-subscription-plan.dart):
/// Basic 8%, Standard 9%, Premium 10%.
class AdminRevenueService {
  AdminRevenueService._();
  static final AdminRevenueService instance = AdminRevenueService._();

  static const List<(String, double)> plans = [
    ('Basic', 0.08),
    ('Standard', 0.09),
    ('Premium', 0.10),
  ];

  /// Always returns one entry per plan, in Basic/Standard/Premium order,
  /// with zeros for plans that have no sales yet.
  Future<List<PlanRevenue>> fetchByPlan() async {
    try {
      final rows =
          await Supabase.instance.client.rpc('admin_revenue_by_plan') as List;
      final byPlan = <String, Map<String, dynamic>>{
        for (final row in rows)
          (row as Map<String, dynamic>)['plan'] as String: row,
      };
      return [
        for (final (name, rate) in plans)
          PlanRevenue(
            plan: name,
            rate: rate,
            tickets: (byPlan[name]?['tickets'] as num?)?.toInt() ?? 0,
            gross: (byPlan[name]?['gross'] as num?)?.toDouble() ?? 0,
            fees: (byPlan[name]?['fees'] as num?)?.toDouble() ?? 0,
            net: (byPlan[name]?['net'] as num?)?.toDouble() ?? 0,
          ),
      ];
    } on PostgrestException catch (e) {
      throw AdminRevenueException(
        'Could not load platform revenue: ${e.message}',
      );
    }
  }
}
