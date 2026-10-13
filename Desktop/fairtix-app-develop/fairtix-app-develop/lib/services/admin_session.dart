class AdminSession {
  AdminSession._();
  static final AdminSession instance = AdminSession._();

  String? _currentEmail;
  DateTime? _memberSince;

  String? get currentEmail => _currentEmail;

  /// When this admin's `public.users` row was created (real
  /// `created_at` from Supabase, set by [AdminAuthService.login]) —
  /// shown on `admin-profile.dart` as "Member Since". Null only if that
  /// value couldn't be parsed.
  DateTime? get memberSince => _memberSince;

  bool get isSignedIn =>
      _currentEmail != null && _currentEmail!.trim().isNotEmpty;

  void signIn(String email, {DateTime? memberSince}) {
    _currentEmail = email.trim();
    _memberSince = memberSince;
  }

  void signOut() {
    _currentEmail = null;
    _memberSince = null;
  }
}
