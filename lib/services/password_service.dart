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
    } catch (_) {
      throw const PasswordChangeException(
        'Could not verify your current password. Check your connection and try again.',
      );
    }

    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw PasswordChangeException(e.message);
    } catch (_) {
      throw const PasswordChangeException(
        'Could not save your new password. Check your connection and try again.',
      );
    }
  }

  // --- Forgot password (signed-out) -----------------------------------------
  // Code-based, matching how signup confirmation already works: Supabase emails
  // a one-time code, the user types it in, then sets a new password. Needs the
  // "Reset password" email template in the Supabase Dashboard
  // (Authentication > Email Templates) to show `{{ .Token }}` instead of only
  // the `{{ .ConfirmationURL }}` link.

  /// Emails a reset code to [email]. Supabase does not reveal whether the
  /// address has an account, so this succeeds either way.
  Future<void> sendResetCode(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      throw PasswordChangeException(e.message);
    } catch (_) {
      throw const PasswordChangeException(
        'Could not send the code. Check your connection and try again.',
      );
    }
  }

  /// Checks the emailed code. On success Supabase opens a short-lived
  /// recovery session, which [setNewPasswordAfterReset] uses.
  Future<void> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim().toLowerCase(),
        token: code.trim(),
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('expired') || m.contains('invalid')) {
        throw const PasswordChangeException(
          'That code is invalid or has expired. Request a new one.',
        );
      }
      throw PasswordChangeException(e.message);
    } catch (_) {
      throw const PasswordChangeException(
        'Could not verify the code. Check your connection and try again.',
      );
    }
  }

  /// Saves the new password, then signs out the recovery session so the user
  /// logs in normally with it. If saving fails the session is kept, so they
  /// can try another password without a new code.
  Future<void> setNewPasswordAfterReset(String newPassword) async {
    final client = Supabase.instance.client;
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw PasswordChangeException(e.message);
    } catch (_) {
      throw const PasswordChangeException(
        'Could not save your new password. Check your connection and try again.',
      );
    }
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  /// Ends a recovery session the user walked away from before finishing.
  Future<void> abandonReset() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}
