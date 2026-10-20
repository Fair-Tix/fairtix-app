import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizer_session.dart';
import 'subscription_plan_service.dart';

/// Thrown when starting or confirming a subscription payment fails.
class OrganizerSubscriptionException implements Exception {
  final String message;

  /// True when PayMongo does not (yet) show the payment as paid. This is
  /// expected while the organizer is still on the payment page, so the plan
  /// screen keeps waiting instead of showing an error.
  final bool paymentPending;

  const OrganizerSubscriptionException(
    this.message, {
    this.paymentPending = false,
  });
}

/// A PayMongo Checkout Session created for a plan purchase.
class SubscriptionCheckout {
  final String checkoutUrl;
  final String sessionId;

  const SubscriptionCheckout({
    required this.checkoutUrl,
    required this.sessionId,
  });
}

/// The plan that was activated after a confirmed payment.
class SubscriptionActivation {
  final String planName;
  final DateTime renewsAt;

  const SubscriptionActivation({
    required this.planName,
    required this.renewsAt,
  });
}

/// Buys an organizer plan through PayMongo.
///
/// Flow (same Edge Functions the ticket checkout uses):
///  1. [startCheckout] asks `paymongo-checkout` for a PayMongo Sandbox
///     Checkout Session for the plan. The price is decided on the server;
///     nothing about the amount is sent from the app.
///  2. The organizer pays on PayMongo's own checkout page.
///  3. [confirmPayment] asks `paymongo-verify`, which checks with PayMongo
///     that the session is PAID and only then activates the plan in
///     `public.organizer_subscriptions` (`fulfill_organizer_subscription`,
///     supabase/organizer_subscription_payment.sql). `paymongo-webhook`
///     activates the same plan independently if the organizer closes the page
///     after paying; both use the session id as the payment reference, so a
///     payment can only ever activate or extend a plan once.
///
/// The app can no longer write `organizer_subscriptions` itself: those client
/// write policies are dropped by organizer_subscription_payment.sql so a plan
/// can't be activated without paying.
class OrganizerSubscriptionService {
  OrganizerSubscriptionService._();
  static final OrganizerSubscriptionService instance =
      OrganizerSubscriptionService._();

  /// Creates the PayMongo Checkout Session for a plan. Pass [planId] (the
  /// `subscription_plans.plan_id` shown on the plan card) whenever you have
  /// it: the server looks the plan up by id, so a rename by the admin can't
  /// point the payment at the wrong plan. [planName] is the fallback.
  Future<SubscriptionCheckout> startCheckout(
    String planName, {
    String? planId,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizerSubscriptionException(
        'You need to be signed in to select a plan.',
      );
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'paymongo-checkout',
        body: planId != null && planId.isNotEmpty
            ? {'planId': planId}
            : {'planName': planName},
      );
      final data = response.data;
      if (data is! Map ||
          data['checkout_url'] == null ||
          data['session_id'] == null) {
        throw OrganizerSubscriptionException(
          (data is Map ? data['error'] as String? : null) ??
              'Could not start the PayMongo checkout.',
        );
      }
      return SubscriptionCheckout(
        checkoutUrl: data['checkout_url'] as String,
        sessionId: data['session_id'] as String,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      throw OrganizerSubscriptionException(
        (details is Map ? details['error'] as String? : null) ??
            'Could not start the PayMongo checkout. Please try again.',
      );
    }
  }

  /// Checks the payment for [sessionId] and, once PayMongo reports it paid,
  /// returns the activated plan and updates the signed-in organizer session.
  ///
  /// Throws an [OrganizerSubscriptionException] with `paymentPending: true`
  /// while the payment hasn't gone through yet.
  Future<SubscriptionActivation> confirmPayment(String sessionId) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'paymongo-verify',
        body: {'sessionId': sessionId},
      );
      final data = response.data;
      if (data is! Map || data['subscription'] != true) {
        throw OrganizerSubscriptionException(
          (data is Map ? data['error'] as String? : null) ??
              'Could not confirm your payment.',
        );
      }

      final planName = data['plan_name'] as String;
      final renewsAt =
          DateTime.tryParse('${data['renews_at']}') ??
          DateTime.now().add(const Duration(days: 30));

      final currentAccount = OrganizerSession.instance.account;
      if (currentAccount != null) {
        // The name alone says nothing about what the plan allows or charges
        // (the admin edits both), so also pull the plan's own export switch
        // and fee rate. If that lookup fails the account keeps its previous
        // values and the next login reloads them from the server.
        var canExport = currentAccount.subscriptionCanExport;
        double? feeRate = currentAccount.subscriptionFeeRate;
        try {
          final plan = await SubscriptionPlanService.instance.fetchPlanByName(
            planName,
          );
          if (plan != null) {
            canExport = plan.canExport;
            feeRate = plan.feeRate;
          }
        } catch (_) {}
        OrganizerSession.instance.updateAccount(
          currentAccount.copyWith(
            subscriptionPlan: planName,
            subscriptionFeeRate: feeRate,
            subscriptionCanExport: canExport,
            subscriptionRenewsAt: renewsAt,
          ),
        );
      }
      return SubscriptionActivation(planName: planName, renewsAt: renewsAt);
    } on FunctionException catch (e) {
      final details = e.details;
      final message =
          (details is Map ? details['error'] as String? : null) ??
          'Could not confirm your payment.';
      // 402 = PayMongo doesn't show it as paid (yet).
      throw OrganizerSubscriptionException(
        message,
        paymentPending: e.status == 402,
      );
    }
  }

  /// Removed: plans can no longer be written straight from the app. Use
  /// [startCheckout] and [confirmPayment].
  @Deprecated('Plans are paid through PayMongo: use startCheckout/confirmPayment.')
  Future<DateTime> selectPlan(String planName) async {
    throw const OrganizerSubscriptionException(
      'Plans must be purchased through PayMongo.',
    );
  }
}
