/// Represents a signed-in FairTix event organizer account, loaded from
/// Supabase Auth + the `public.users` / `public.organizer_subscriptions`
/// Postgres tables (see supabase/schema.sql) by
/// `OrganizerAuthService.login()`.
class OrganizerAccount {
  final String id;
  final String fullName;
  final String email;
  final String organizationName;

  /// Current subscription plan name as saved by the admin in Platform
  /// Settings (e.g. 'Basic'), or null if the organizer has not selected a
  /// plan yet. Display only: use [subscriptionFeeRate] and
  /// [subscriptionCanExport] for behaviour, never the name.
  final String? subscriptionPlan;

  /// Fraction of each primary sale kept by FairTix on the current plan
  /// (0.08 = 8%), read from `subscription_plans.platform_fee_rate`. Null when
  /// there is no active plan.
  final double? subscriptionFeeRate;

  /// When the current subscription period renews, or null if there is no
  /// active subscription.
  final DateTime? subscriptionRenewsAt;

  /// Whether the current plan includes report export (the "Allow report
  /// export" switch on the plan in Admin > Platform Settings). The server
  /// enforces the same flag in `organizer_can_export()`.
  final bool subscriptionCanExport;

  /// Raw `public.users.id_verification_status` value: 'pending',
  /// 'verified', or 'rejected'. Used by the login flow to decide whether
  /// to route into the dashboard, to the "verification pending" screen,
  /// or to block the sign-in.
  final String idVerificationStatus;

  /// Storage path of the uploaded "Proof of Venue Booking" document, or
  /// null if it hasn't been uploaded yet. Registration collects this file
  /// but often can't upload it immediately (Supabase requires an active
  /// session, which doesn't exist right after `signUp()` when email
  /// confirmation is required) — [OrganizerLoginScreen] checks this field
  /// after a successful login and routes to
  /// [OrganizerDocumentUploadScreen] if it's still null.
  final String? venueProofUrl;

  /// Storage path of the uploaded "Valid Event Permit" document. Same
  /// null-until-uploaded behavior as [venueProofUrl].
  final String? eventPermitUrl;

  /// End date of the organizer's most recent subscription when it has run
  /// out, or null when they have never subscribed or the plan is current.
  /// Set at login so an expired organizer can still sign in and view their
  /// account while subscription features stay locked until they renew.
  final DateTime? subscriptionExpiredAt;

  const OrganizerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organizationName,
    this.subscriptionPlan,
    this.subscriptionFeeRate,
    this.subscriptionRenewsAt,
    this.subscriptionCanExport = false,
    this.idVerificationStatus = 'pending',
    this.venueProofUrl,
    this.eventPermitUrl,
    this.subscriptionExpiredAt,
  });

  /// True once an admin has approved the organizer application.
  bool get isApproved => idVerificationStatus == 'verified';

  /// True when there is a plan whose period has not run out yet. Uses the same
  /// UTC date the server uses (`current_date between start_date and end_date`).
  bool get hasActiveSubscription {
    if (subscriptionPlan == null) return false;
    final renews = subscriptionRenewsAt;
    if (renews == null) return true;
    final today = DateTime.now().toUtc();
    final todayKey = today.year * 10000 + today.month * 100 + today.day;
    final renewKey = renews.year * 10000 + renews.month * 100 + renews.day;
    return renewKey >= todayKey;
  }

  /// True when the organizer had a plan that has since run out.
  bool get subscriptionExpired =>
      !hasActiveSubscription &&
      (subscriptionExpiredAt != null || subscriptionPlan != null);

  /// Whether both proof-of-organization documents are on file. Login
  /// routing uses this to decide whether the organizer still needs to be
  /// sent to [OrganizerDocumentUploadScreen] before they can be queued
  /// for admin review.
  bool get hasSubmittedDocuments => venueProofUrl != null && eventPermitUrl != null;

  /// Single-letter avatar shown in the sidebar/top bar/profile screen.
  String get avatarInitial =>
      organizationName.isNotEmpty ? organizationName[0].toUpperCase() : '?';

  OrganizerAccount copyWith({
    String? subscriptionPlan,
    double? subscriptionFeeRate,
    DateTime? subscriptionRenewsAt,
    bool? subscriptionCanExport,
    String? venueProofUrl,
    String? eventPermitUrl,
    DateTime? subscriptionExpiredAt,
  }) {
    return OrganizerAccount(
      id: id,
      fullName: fullName,
      email: email,
      organizationName: organizationName,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionFeeRate: subscriptionFeeRate ?? this.subscriptionFeeRate,
      subscriptionRenewsAt:
          subscriptionRenewsAt ?? this.subscriptionRenewsAt,
      subscriptionCanExport:
          subscriptionCanExport ?? this.subscriptionCanExport,
      idVerificationStatus: idVerificationStatus,
      venueProofUrl: venueProofUrl ?? this.venueProofUrl,
      eventPermitUrl: eventPermitUrl ?? this.eventPermitUrl,
      subscriptionExpiredAt: subscriptionExpiredAt ?? this.subscriptionExpiredAt,
    );
  }
}
