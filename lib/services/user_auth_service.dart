import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'user_session.dart';

/// Thrown when an eventgoer auth action (login, register, OTP) fails.
class UserAuthException implements Exception {
  final String message;
  const UserAuthException(this.message);
}

/// Handles eventgoer (buyer) authentication.
///
/// [register], [verifyRegistrationOtp], and [resendRegistrationOtp] are
/// wired to real Supabase Auth. [login] still checks the hardcoded
/// [_testAccount] pending Phase 1's login work (see
/// docs/FairTix-Backend-Roadmap.md) — replace it the same way, with
/// `supabase.auth.signInWithPassword(...)` followed by loading the
/// matching row from the Postgres `users` table into [UserSession].
///
/// Exactly one seeded test account exists so the login -> dashboard ->
/// navigation flow can be exercised end-to-end before real login is wired
/// up. No other sample accounts are created anywhere in the app.
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

  /// Creates a new eventgoer account in Supabase Auth. A `public.users`
  /// row is auto-created by the `on_auth_user_created` trigger
  /// (see supabase/schema.sql), populated from [data] below.
  ///
  /// Supabase's own "Confirm signup" email is what carries the 6-digit
  /// code shown on [OtpVerificationScreen] — in the Supabase Dashboard,
  /// under Authentication > Email Templates > Confirm signup, the template
  /// must use `{{ .Token }}` (not `{{ .ConfirmationURL }}`) for this to
  /// work as a code instead of a magic link.
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required DateTime birthDate,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName.trim(),
          'username': username.trim(),
          'phone': phone.trim(),
          'birth_date':
              '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
        },
      );
      if (response.user == null) {
        throw const UserAuthException(
          'Could not create your account. Please try again.',
        );
      }
    } on AuthException catch (e) {
      throw UserAuthException(e.message);
    }
  }

  /// Confirms the 6-digit code from the "Confirm signup" email against
  /// Supabase Auth, completing registration and creating a session.
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        token: token,
      );
    } on AuthException catch (e) {
      throw UserAuthException(e.message);
    }
  }

  /// Asks Supabase Auth to send a fresh signup confirmation code to
  /// [email], for the OTP screen's "Resend" link.
  Future<void> resendRegistrationOtp({required String email}) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      throw UserAuthException(e.message);
    }
  }

  void logout() {
    UserSession.instance.signOut();
  }
}
