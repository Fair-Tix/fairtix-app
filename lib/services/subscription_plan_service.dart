import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_plan.dart';

/// Thrown when loading or saving subscription plans fails.
class SubscriptionPlanException implements Exception {
  final String message;
  const SubscriptionPlanException(this.message);
}

/// Reads and saves the organizer subscription plans (`public.subscription_plans`).
///
/// Organizers read the ACTIVE plans (the plan screen); the admin reads all of
/// them and saves the whole list from Platform Settings. Saving goes through
/// the admin-only `admin_save_subscription_plans` function, which also
/// validates the plans, so the app cannot write the table directly.
class SubscriptionPlanService {
  SubscriptionPlanService._();
  static final SubscriptionPlanService instance = SubscriptionPlanService._();

  /// Plans in display order. [activeOnly] hides plans the admin switched off.
  Future<List<SubscriptionPlan>> fetchPlans({bool activeOnly = true}) async {
    try {
      final base = Supabase.instance.client
          .from('subscription_plans')
          .select();
      final rows = await (activeOnly ? base.eq('is_active', true) : base)
          .order('sort_order', ascending: true)
          .order('monthly_fee', ascending: true);
      return [for (final row in rows) SubscriptionPlan.fromRow(row)];
    } on PostgrestException catch (e) {
      throw SubscriptionPlanException(_friendly(e, 'Could not load the plans'));
    }
  }

  /// The plan called [name] (case-insensitive), including plans the admin has
  /// since switched off, because existing subscribers keep them. Null when no
  /// plan has that name.
  Future<SubscriptionPlan?> fetchPlanByName(String name) async {
    final wanted = name.trim().toLowerCase();
    final plans = await fetchPlans(activeOnly: false);
    for (final plan in plans) {
      if (plan.name.trim().toLowerCase() == wanted) return plan;
    }
    return null;
  }

  /// Saves [plans] (admin only). The list order becomes the display order;
  /// existing plans left out are switched off, never deleted.
  Future<void> savePlans(List<SubscriptionPlan> plans) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_save_subscription_plans',
        params: {'p_plans': [for (final plan in plans) plan.toJson()]},
      );
    } on PostgrestException catch (e) {
      throw SubscriptionPlanException(_friendly(e, 'Could not save the plans'));
    }
  }

  String _friendly(PostgrestException e, String prefix) {
    // 42P01 / PGRST205 = table missing, PGRST202 = function missing: the SQL
    // file has not been run yet.
    if (e.code == '42P01' || e.code == 'PGRST205' || e.code == 'PGRST202') {
      return 'Subscription plans are not set up yet: run '
          'supabase/subscription_plans.sql in the Supabase SQL Editor first.';
    }
    return '$prefix: ${e.message}';
  }
}
