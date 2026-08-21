import '../models/organizer.dart';
import 'organizer_session.dart';

/// Thrown when an organizer login attempt fails.
class OrganizerAuthException implements Exception {
  final String message;
  const OrganizerAuthException(this.message);
}

/// Handles organizer authentication.
///
/// TODO(backend): Replace the credential check in [login] with
/// `FirebaseAuth.instance.signInWithEmailAndPassword(...)`, then load the
/// matching organizer profile from Cloud Firestore (see Chapter III Data
/// Dictionary: Users) into [OrganizerSession] instead of the hardcoded
/// [_testAccount]. [logout] should call `FirebaseAuth.instance.signOut()`
/// in addition to clearing the local session.
///
/// Exactly one seeded test account exists so the login -> dashboard ->
/// navigation flow can be exercised end-to-end before a real backend is
/// connected. No other sample accounts are created anywhere in the app.
class OrganizerAuthService {
  OrganizerAuthService._();
  static final OrganizerAuthService instance = OrganizerAuthService._();

  static const String _testEmail = 'organizer@fairtix.test';
  static const String _testPassword = 'FairTix123!';

  static final OrganizerAccount _testAccount = OrganizerAccount(
    id: 'test-organizer-001',
    fullName: 'Test Organizer',
    email: _testEmail,
    organizationName: 'FairTix Test Organization',
    subscriptionPlan: 'Basic',
    subscriptionRenewsAt: DateTime.now().add(const Duration(days: 30)),
  );

  /// Shown on the login screen so testers know what to type. Set this to an
  /// empty string once real authentication is wired in.
  static const String debugCredentialsHint = '$_testEmail / $_testPassword';

  Future<OrganizerAccount> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Simulate network latency so the loading state is visible, matching
    // how a real backend call would behave.
    await Future.delayed(const Duration(milliseconds: 400));

    if (normalizedEmail != _testEmail.toLowerCase() ||
        password != _testPassword) {
      throw const OrganizerAuthException(
        'Invalid email or password. Please try again.',
      );
    }

    OrganizerSession.instance.signIn(_testAccount);
    return _testAccount;
  }

  void logout() {
    OrganizerSession.instance.signOut();
  }
}
