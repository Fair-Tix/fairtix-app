import '../models/app_user.dart';

/// Holds the currently signed-in eventgoer for the lifetime of the app run.
///
/// This is intentionally a simple in-memory singleton so every screen can
/// read the active account (name, email, verification status, etc.)
/// without threading it through constructors. When real authentication is
/// added, [signIn] / [signOut] should be driven by the auth service (e.g.
/// in response to a Supabase `onAuthStateChange` event) instead of
/// being called directly from UI code.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  AppUser? _account;

  AppUser? get account => _account;
  bool get isSignedIn => _account != null;

  void signIn(AppUser account) {
    _account = account;
  }

  /// Replaces the current account (e.g. after profile fields change),
  /// keeping the same identity.
  void updateAccount(AppUser account) {
    _account = account;
  }

  void signOut() {
    _account = null;
  }
}
