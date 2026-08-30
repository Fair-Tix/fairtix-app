import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organizer.dart';

/// Holds the currently signed-in organizer for the lifetime of the app run.
///
/// This is intentionally a simple in-memory singleton so every screen can
/// read the active account (name, avatar, subscription, etc.) without
/// threading it through constructors. When real authentication is added,
/// [signIn] / [signOut] should be driven by the auth service (e.g. in
/// response to a Supabase `onAuthStateChange` event) instead of being
/// called directly from UI code.
class OrganizerSession {
  OrganizerSession._();
  static final OrganizerSession instance = OrganizerSession._();

  OrganizerAccount? _account;

  OrganizerAccount? get account => _account;
  bool get isSignedIn => _account != null;

  static String? planNameForMonthlyFee(num? fee) {
    switch (fee) {
      case 299:
        return 'Basic';
      case 699:
        return 'Standard';
      case 1499:
        return 'Premium';
      default:
        return null;
    }
  }

  static int? monthlyFeeForPlan(String? plan) {
    switch (plan) {
      case 'Basic':
        return 299;
      case 'Standard':
        return 699;
      case 'Premium':
        return 1499;
      default:
        return null;
    }
  }

  void signIn(OrganizerAccount account) {
    _account = account;
  }

  /// Replaces the current account (e.g. after a subscription change),
  /// keeping the same identity.
  void updateAccount(OrganizerAccount account) {
    _account = account;
    _persistSubscription(account);
  }

  Future<void> _persistSubscription(OrganizerAccount account) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || account.subscriptionPlan == null) {
      return;
    }

    final monthlyFee = monthlyFeeForPlan(account.subscriptionPlan);
    if (monthlyFee == null) {
      return;
    }

    final now = DateTime.now();
    final startDate = _isoDate(now);
    final endDate = _isoDate(now.add(const Duration(days: 30)));

    try {
      final response = await Supabase.instance.client
          .from('organizer_subscriptions')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false)
          .limit(1);

      final rows = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );

      if (rows.isNotEmpty) {
        await Supabase.instance.client
            .from('organizer_subscriptions')
            .update({
              'monthly_fee': monthlyFee,
              'start_date': startDate,
              'end_date': endDate,
              'status': 'active',
            })
            .eq('user_id', userId)
            .order('start_date', ascending: false)
            .limit(1);
      } else {
        await Supabase.instance.client
            .from('organizer_subscriptions')
            .insert({
              'user_id': userId,
              'monthly_fee': monthlyFee,
              'start_date': startDate,
              'end_date': endDate,
              'status': 'active',
            });
      }
    } catch (_) {
      // Intentionally silent: the in-memory session should still work even
      // when the backend write is unavailable or the table is not yet seeded.
    }
  }

  String _isoDate(DateTime value) {
    return value.toIso8601String().split('T').first;
  }

  void signOut() {
    _account = null;
  }
}
