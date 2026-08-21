/// Represents a signed-in FairTix event organizer account.
///
/// This is a lightweight, backend-agnostic model. When real authentication
/// (Firebase Auth) and a real data source (Cloud Firestore `users`
/// collection) are wired in, this model's fields should map onto the
/// corresponding remote fields (see Chapter III Data Dictionary: Users)
/// rather than changing shape, so screens that already read from
/// [OrganizerAccount] keep working unchanged.
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

  const OrganizerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organizationName,
    this.subscriptionPlan,
    this.subscriptionRenewsAt,
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
    );
  }
}
