/// The signed-in eventgoer's profile, loaded from Supabase Auth + the
/// `public.users` Postgres table (see supabase/schema.sql) by
/// `UserAuthService.login()`.
class AppUser {
  const AppUser({
    required this.fullName,
    required this.username,
    required this.email,
    required this.idType,
    this.isVerified = true,
    this.idVerificationStatus = 'verified',
    this.idDocumentUrl,
  });

  final String fullName;
  final String username;
  final String email;
  final String idType;

  /// Convenience flag; true iff [idVerificationStatus] == 'verified'.
  final bool isVerified;

  /// Raw `public.users.id_verification_status` value: 'pending',
  /// 'verified', or 'rejected'. Used by the login flow to decide whether
  /// to route into the app, back into the ID-upload steps, or to the
  /// "under review" screen.
  final String idVerificationStatus;

  /// `public.users.id_document_url` — null means the eventgoer hasn't
  /// uploaded an ID yet (still mid-registration), as distinct from
  /// 'pending' meaning it's uploaded but not yet reviewed by an admin.
  final String? idDocumentUrl;

  /// Builds an [AppUser] from a `public.users` row (as returned by
  /// `supabase.from('users').select().eq('id', ...).single()`).
  factory AppUser.fromRow(Map<String, dynamic> row) {
    final status = (row['id_verification_status'] as String?) ?? 'pending';
    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    final username = (row['username'] as String?)?.trim() ?? '';
    return AppUser(
      fullName: fullName.isNotEmpty ? fullName : 'Eventgoer',
      username: username.isNotEmpty ? username : '',
      email: (row['email'] as String?) ?? '',
      idType: (row['id_type'] as String?) ?? 'Not submitted',
      isVerified: status == 'verified',
      idVerificationStatus: status,
      idDocumentUrl: row['id_document_url'] as String?,
    );
  }

  /// Two-letter initials for the avatar, e.g. "Heron Dave Mahilum" -> "HM".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
