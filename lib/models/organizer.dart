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

  const OrganizerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organizationName,
    this.subscriptionPlan,
    this.subscriptionRenewsAt,
    this.idVerificationStatus = 'pending',
    this.venueProofUrl,
    this.eventPermitUrl,
  });

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
    DateTime? subscriptionRenewsAt,
    String? venueProofUrl,
    String? eventPermitUrl,
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
      venueProofUrl: venueProofUrl ?? this.venueProofUrl,
      eventPermitUrl: eventPermitUrl ?? this.eventPermitUrl,
    );
  }
}
