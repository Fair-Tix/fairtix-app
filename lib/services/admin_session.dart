class AdminSession {
  AdminSession._();
  static final AdminSession instance = AdminSession._();

  String? _currentEmail;

  String? get currentEmail => _currentEmail;
  bool get isSignedIn =>
      _currentEmail != null && _currentEmail!.trim().isNotEmpty;

  void signIn(String email) {
    _currentEmail = email.trim();
  }

  void signOut() {
    _currentEmail = null;
  }
}
