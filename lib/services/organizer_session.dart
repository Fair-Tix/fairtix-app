import '../models/organizer.dart';

/// Holds the currently signed-in organizer for the lifetime of the app run.
///
/// This is intentionally a simple in-memory singleton so every screen can
/// read the active account (name, avatar, subscription, etc.) without
/// threading it through constructors. When real authentication is added,
/// [signIn] / [signOut] should be driven by the auth service (e.g. in
/// response to a Supabase `onAuthStateChange` event) instead of being
/// called directly from UI code.
class OrganizerSession {
  OrganizerSession._();
  static final OrganizerSession instance = OrganizerSession._();

  OrganizerAccount? _account;

  OrganizerAccount? get account => _account;
  bool get isSignedIn => _account != null;

  void signIn(OrganizerAccount account) {
    _account = account;
  }

  /// Replaces the current account (e.g. after a subscription change),
  /// keeping the same identity.
  void updateAccount(OrganizerAccount account) {
    _account = account;
  }

  void signOut() {
    _account = null;
  }
}
