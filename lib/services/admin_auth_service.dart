import 'admin_session.dart';

/// thrown when an admin login attempt fails
class AdminAuthException implements Exception {
  final String message;
  const AdminAuthException(this.message);
}

/// handles admin authentication for the portal.
///
/// this local account keeps the portal flow testable until Firebase
/// Authentication and admin custom claims are connected
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  static const String _testEmail = 'admin@fairtix.com';
  static const String _testPassword = '123';

  static const String debugCredentialsHint = '$_testEmail / $_testPassword';

  Future<void> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final normalizedEmail = email.trim();
    if (normalizedEmail.toLowerCase() != _testEmail ||
        password != _testPassword) {
      throw const AdminAuthException(
        'Invalid email or password. Please try again.',
      );
    }

    AdminSession.instance.signIn(normalizedEmail);
  }

  void logout() {
    AdminSession.instance.signOut();
  }
}
