/// One row of `public.users` as seen by an admin, used by
/// `admin-accounts.dart` (all roles) and
/// `admin-organizer-applications.dart` (role = 'organizer' only) to drive
/// the manual ID/document review flow.
///
/// This intentionally mirrors raw Postgres enum values ('pending' /
/// 'verified' / 'rejected', 'active' / 'suspended' / 'deactivated', etc.)
/// rather than a UI-friendly enum, since the two screens display and
/// filter on these differently (e.g. the organizer screen labels
/// 'verified' as "Approved").
class AdminUserSummary {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String? organizationName;
  final String role; // 'buyer' | 'organizer' | 'admin'
  final String accountStatus; // 'active' | 'suspended' | 'deactivated'
  final String idVerificationStatus; // 'pending' | 'verified' | 'rejected'
  final String? idType;
  final String? idDocumentUrl;
  final String? selfiePhotoUrl;
  final String? venueProofUrl;
  final String? eventPermitUrl;
  final DateTime? createdAt;

  const AdminUserSummary({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.organizationName,
    required this.role,
    required this.accountStatus,
    required this.idVerificationStatus,
    this.idType,
    this.idDocumentUrl,
    this.selfiePhotoUrl,
    this.venueProofUrl,
    this.eventPermitUrl,
    this.createdAt,
  });

  factory AdminUserSummary.fromRow(Map<String, dynamic> row) {
    return AdminUserSummary(
      id: row['id'] as String,
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : '(No name on file)',
      username: (row['username'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      organizationName: row['organization_name'] as String?,
      role: (row['role'] as String?) ?? 'buyer',
      accountStatus: (row['account_status'] as String?) ?? 'active',
      idVerificationStatus:
          (row['id_verification_status'] as String?) ?? 'pending',
      idType: row['id_type'] as String?,
      idDocumentUrl: row['id_document_url'] as String?,
      selfiePhotoUrl: row['selfie_photo_url'] as String?,
      venueProofUrl: row['venue_proof_url'] as String?,
      eventPermitUrl: row['event_permit_url'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }

  /// Whether this row has anything an admin could actually review yet.
  /// A buyer needs both the ID photo and the selfie on file; an organizer
  /// needs both proof-of-org documents. Until then "Review" would just
  /// open an empty dialog, so screens use this to decide whether to show
  /// a disabled/placeholder state instead.
  bool get hasReviewableDocuments => role == 'organizer'
      ? (venueProofUrl != null || eventPermitUrl != null)
      : (idDocumentUrl != null || selfiePhotoUrl != null);
}
