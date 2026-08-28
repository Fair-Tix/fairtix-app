import '../models/app_user.dart';
import 'user_session.dart';

/// Thrown when an eventgoer login attempt fails.
class UserAuthException implements Exception {
  final String message;
  const UserAuthException(this.message);
}

/// Handles eventgoer (buyer) authentication.
///
/// TODO(backend): Replace the credential check in [login] with
/// `supabase.auth.signInWithPassword(...)`, then load the matching user
/// profile from the Postgres `users` table (see Chapter III Data
/// Dictionary: Users, and supabase/schema.sql) into [UserSession] instead
/// of the hardcoded [_testAccount]. [logout] should call
/// `supabase.auth.signOut()` in addition to clearing the local session.
/// See docs/FairTix-Backend-Roadmap.md, Phase 1.
///
/// Exactly one seeded test account exists so the login -> dashboard ->
/// navigation flow can be exercised end-to-end before a real backend is
/// connected. No other sample accounts are created anywhere in the app.
class UserAuthService {
  UserAuthService._();
  static final UserAuthService instance = UserAuthService._();

  static const String _testEmail = 'eventgoer@fairtix.test';
  static const String _testPassword = 'FairTix123!';

  static const AppUser _testAccount = AppUser(
    fullName: 'Test Eventgoer',
    username: '@testeventgoer',
    email: _testEmail,
    idType: 'Philippine National ID (PhilSys)',
    isVerified: true,
  );

  /// Shown on the login screen so testers know what to type. Set this to an
  /// empty string once real authentication is wired in.
  static const String debugCredentialsHint = '$_testEmail / $_testPassword';

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Simulate network latency so the loading state is visible, matching
    // how a real backend call would behave.
    await Future.delayed(const Duration(milliseconds: 400));

    if (normalizedEmail != _testEmail.toLowerCase() ||
        password != _testPassword) {
      throw const UserAuthException(
        'Invalid email or password. Please try again.',
      );
    }

    UserSession.instance.signIn(_testAccount);
    return _testAccount;
  }

  void logout() {
    UserSession.instance.signOut();
  }
}
