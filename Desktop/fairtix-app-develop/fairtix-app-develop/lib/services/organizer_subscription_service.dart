import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizer_session.dart';

/// Thrown when persisting a subscription plan choice fails.
class OrganizerSubscriptionException implements Exception {
  final String message;
  const OrganizerSubscriptionException(this.message);
}

/// Persists the organizer's plan choice from
/// `organizer-subscription-plan.dart` to `public.organizer_subscriptions`.
///
/// `organizer_subscriptions` (Table 7 in the Data Dictionary) has no
/// plan-name column, only `monthly_fee` — this mirrors the same fee↔name
/// mapping `OrganizerAuthService._planNameFromMonthlyFee` uses on login
/// (₱299 = Basic, ₱699 = Standard, ₱1,499 = Premium).
///
/// Requires the `org_subs_insert_own` / `org_subs_update_own_or_admin` RLS
/// policies added to supabase/policies.sql — the original schema only
/// allowed admin writes here, which would have silently rejected every
/// plan selection.
class OrganizerSubscriptionService {
  OrganizerSubscriptionService._();
  static final OrganizerSubscriptionService instance =
      OrganizerSubscriptionService._();

  static const Map<String, num> _feeForPlan = {
    'Basic': 299,
    'Standard': 699,
    'Premium': 1499,
  };

  /// Selects (or switches to) [planName] for the signed-in organizer.
  ///
  /// If the organizer already has an active subscription row, it's updated
  /// in place (new fee + a fresh 30-day period) rather than inserting a
  /// second "active" row for the same organizer — the schema has no unique
  /// constraint preventing that, and `OrganizerAuthService.login()` only
  /// ever reads the single most-recent active row back, so keeping one row
  /// per organizer avoids ambiguity.
  Future<DateTime> selectPlan(String planName) async {
    final fee = _feeForPlan[planName];
    if (fee == null) {
      throw OrganizerSubscriptionException('Unknown plan "$planName".');
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizerSubscriptionException(
        'You need to be signed in to select a plan.',
      );
    }

    final now = DateTime.now();
    final renewsAt = now.add(const Duration(days: 30));

    try {
      final existing = await Supabase.instance.client
          .from('organizer_subscriptions')
          .select('subscription_id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();

      final payload = {
        'user_id': userId,
        'start_date': now.toIso8601String().split('T').first,
        'end_date': renewsAt.toIso8601String().split('T').first,
        'status': 'active',
        'monthly_fee': fee,
      };

      if (existing != null) {
        await Supabase.instance.client
            .from('organizer_subscriptions')
            .update(payload)
            .eq('subscription_id', existing['subscription_id']);
      } else {
        await Supabase.instance.client
            .from('organizer_subscriptions')
            .insert(payload);
      }
    } on PostgrestException catch (e) {
      throw OrganizerSubscriptionException(
        'Could not save your plan: ${e.message}',
      );
    }

    final currentAccount = OrganizerSession.instance.account;
    if (currentAccount != null) {
      OrganizerSession.instance.updateAccount(
        currentAccount.copyWith(
          subscriptionPlan: planName,
          subscriptionRenewsAt: renewsAt,
        ),
      );
    }

    return renewsAt;
  }
}
