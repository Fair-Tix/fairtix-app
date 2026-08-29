import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a password-change action fails (wrong current password,
/// weak new password, expired session, network/auth error, etc.).
class PasswordChangeException implements Exception {
  final String message;
  const PasswordChangeException(this.message);
}

/// Shared "change my password" flow for all three FairTix apps
/// (eventgoer, organizer, admin) — they're all just Supabase Auth users
/// under the hood, so one implementation covers all three profile
/// screens. Per the capstone's Account Verification rules (Chapter I,
/// Definition of Terms), this is the *only* self-service profile edit
/// allowed: full name and contact details stay locked to the verified ID
/// document once an account is registered, so there is no corresponding
/// "update name/email" method here by design.
class PasswordService {
  PasswordService._();
  static final PasswordService instance = PasswordService._();

  /// Changes the signed-in user's password.
  ///
  /// Supabase's `auth.updateUser()` doesn't itself ask for the current
  /// password, so [currentPassword] is verified first by re-running
  /// `signInWithPassword` against the session's own email. This also
  /// guards against someone changing the password on a device that was
  /// left signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = Supabase.instance.client;
    final email = client.auth.currentUser?.email;
    if (email == null) {
      throw const PasswordChangeException(
        'Your session has expired. Please log in again.',
      );
    }

    try {
      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw const PasswordChangeException('Current password is incorrect.');
    }

    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw PasswordChangeException(e.message);
    }
  }
}
