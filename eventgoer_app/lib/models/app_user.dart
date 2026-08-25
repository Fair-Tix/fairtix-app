/// Placeholder "current user" model for UI scaffolding.
/// TODO: replace with the real user profile pulled from Firebase Auth +
/// the USERS Firestore document once the backend is wired up.
class AppUser {
  const AppUser({
    required this.fullName,
    required this.username,
    required this.email,
    required this.idType,
    this.isVerified = true,
  });

  final String fullName;
  final String username;
  final String email;
  final String idType;
  final bool isVerified;

  /// Two-letter initials for the avatar, e.g. "Heron Dave Mahilum" -> "HM".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
