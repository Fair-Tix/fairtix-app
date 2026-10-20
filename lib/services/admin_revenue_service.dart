import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_plan_service.dart';

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

  /// Percent label such as 8% or 8.5% (admin-set rates need not be whole).
  String get rateLabel => formatFeeRate(rate);
}

/// Formats a fee fraction as a percent: 0.08 -> 8%, 0.085 -> 8.5%.
String formatFeeRate(double rate) {
  final percent = rate * 100;
  if (percent == percent.roundToDouble()) {
    return '${percent.toStringAsFixed(0)}%';
  }
  return '${percent.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')}%';
}

/// Admin-only platform revenue, backed by the `admin_revenue_by_plan()`
/// Postgres function (supabase/revenue_functions.sql), which sums the rows
/// the purchase trigger writes to `public.organizer_fees`.
///
/// Plans and their fee rates are admin-editable (`public.subscription_plans`),
/// so nothing about them is hardcoded here.
class AdminRevenueService {
  AdminRevenueService._();
  static final AdminRevenueService instance = AdminRevenueService._();

  /// One entry per fee rate that has sales, plus a zero entry for every active
  /// plan whose rate has none yet, lowest rate first. [from] is inclusive and
  /// [to] exclusive; either may be null for no limit on that side.
  Future<List<PlanRevenue>> fetchByPlan({DateTime? from, DateTime? to}) async {
    try {
      final rows =
          await Supabase.instance.client.rpc(
                'admin_revenue_by_plan',
                params: {
                  'p_from': from?.toUtc().toIso8601String(),
                  'p_to': to?.toUtc().toIso8601String(),
                },
              )
              as List;

      int key(double rate) => (rate * 10000).round();
      final byRate = <int, PlanRevenue>{};
      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final rate = (row['rate'] as num?)?.toDouble() ?? 0;
        byRate[key(rate)] = PlanRevenue(
          plan: (row['plan'] as String?) ?? formatFeeRate(rate),
          rate: rate,
          tickets: (row['tickets'] as num?)?.toInt() ?? 0,
          gross: (row['gross'] as num?)?.toDouble() ?? 0,
          fees: (row['fees'] as num?)?.toDouble() ?? 0,
          net: (row['net'] as num?)?.toDouble() ?? 0,
        );
      }

      // Active plans with no sales in this range still get a zero row. If the
      // plan list can't be loaded, show just the rows that have sales.
      try {
        final plans = await SubscriptionPlanService.instance.fetchPlans();
        final names = <int, List<String>>{};
        for (final plan in plans) {
          names.putIfAbsent(key(plan.feeRate), () => []).add(plan.name);
        }
        for (final entry in names.entries) {
          byRate.putIfAbsent(
            entry.key,
            () => PlanRevenue(
              plan: entry.value.join(' / '),
              rate: entry.key / 10000,
              tickets: 0,
              gross: 0,
              fees: 0,
              net: 0,
            ),
          );
        }
      } catch (_) {}

      return byRate.values.toList()..sort((a, b) => a.rate.compareTo(b.rate));
    } on PostgrestException catch (e) {
      throw AdminRevenueException(
        'Could not load platform revenue: ${e.message}',
      );
    }
  }
}
