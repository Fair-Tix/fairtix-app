/// Represents a signed-in FairTix event organizer account, loaded from
/// Supabase Auth + the `public.users` / `public.organizer_subscriptions`
/// Postgres tables (see supabase/schema.sql) by
/// `OrganizerAuthService.login()`.
class OrganizerAccount {
  final String id;
  final String fullName;
  final String email;
  final String organizationName;

  /// Current subscription tier name ('Basic' | 'Standard' | 'Premium'), or
  /// null if the organizer has not selected a plan yet.
  final String? subscriptionPlan;

  /// When the current subscription period renews, or null if there is no
  /// active subscription.
  final DateTime? subscriptionRenewsAt;

  /// Raw `public.users.id_verification_status` value: 'pending',
  /// 'verified', or 'rejected'. Used by the login flow to decide whether
  /// to route into the dashboard, to the "verification pending" screen,
  /// or to block the sign-in.
  final String idVerificationStatus;

  const OrganizerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organizationName,
    this.subscriptionPlan,
    this.subscriptionRenewsAt,
    this.idVerificationStatus = 'pending',
  });

  /// Single-letter avatar shown in the sidebar/top bar/profile screen.
  String get avatarInitial =>
      organizationName.isNotEmpty ? organizationName[0].toUpperCase() : '?';

  OrganizerAccount copyWith({
    String? subscriptionPlan,
    DateTime? subscriptionRenewsAt,
  }) {
    return OrganizerAccount(
      id: id,
      fullName: fullName,
      email: email,
      organizationName: organizationName,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionRenewsAt:
          subscriptionRenewsAt ?? this.subscriptionRenewsAt,
      idVerificationStatus: idVerificationStatus,
    );
  }
}
