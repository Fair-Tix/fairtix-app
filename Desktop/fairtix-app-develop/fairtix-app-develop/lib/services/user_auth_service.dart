import 'dart:typed_data';

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
/// [register], [verifyRegistrationOtp], [resendRegistrationOtp], and
/// [login] are all wired to real Supabase Auth. [login] calls
/// `supabase.auth.signInWithPassword(...)`, then loads the matching row
/// from the Postgres `public.users` table into [UserSession].
class UserAuthService {
  UserAuthService._();
  static final UserAuthService instance = UserAuthService._();

  /// Shown on the login screen so testers know what to type. Left empty
  /// now that [login] hits real Supabase Auth — there's no single shared
  /// test account anymore, each tester registers their own.
  static const String debugCredentialsHint = '';

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    AuthResponse response;
    try {
      response = await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw UserAuthException(e.message);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const UserAuthException(
        'Invalid email or password. Please try again.',
      );
    }

    final Map<String, dynamic> row;
    try {
      row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();
    } on PostgrestException catch (e) {
      throw UserAuthException('Could not load your account details: ${e.message}');
    }

    final account = AppUser.fromRow(row);
    UserSession.instance.signIn(account);
    return account;
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

  /// Uploads the buyer's government/school ID photo to the private
  /// `identity_docs` Storage bucket (see supabase/policies.sql) and
  /// records the storage path + chosen [idType] on their `public.users`
  /// row, resetting `id_verification_status` back to `pending` so an
  /// admin re-reviews it (covers first-time submissions as well as
  /// re-submissions after a rejection).
  ///
  /// Requires an active Supabase Auth session, which exists once
  /// [verifyRegistrationOtp] has completed earlier in the registration
  /// flow. Returns the storage path the file was saved under.
  Future<String> uploadIdentityDocument({
    required String idType,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const UserAuthException(
        'Your session has expired. Please verify your email again before uploading an ID.',
      );
    }

    final ext = fileExtension.replaceFirst('.', '').toLowerCase();
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path = '$userId/id_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}';

    try {
      await Supabase.instance.client.storage.from('identity_docs').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await Supabase.instance.client.from('users').update({
        'id_document_url': path,
        'id_type': idType,
        'id_verification_status': 'pending',
      }).eq('id', userId);
    } on StorageException catch (e) {
      throw UserAuthException('Could not upload your ID: ${e.message}');
    } on PostgrestException catch (e) {
      throw UserAuthException('Could not save your ID details: ${e.message}');
    }

    return path;
  }

  /// Uploads the buyer's live verification selfie to the same private
  /// `identity_docs` Storage bucket used for the ID photo (owner-only —
  /// see supabase/policies.sql) and records the resulting path on
  /// `public.users.selfie_photo_url`.
  ///
  /// This does NOT perform an automated face match against the ID photo
  /// or compute `face_embedding_hash` — both need a server-side model
  /// and are tracked as a follow-up Supabase Edge Function in
  /// docs/FairTix-Backend-Roadmap.md. Until that exists, the account
  /// stays `id_verification_status = 'pending'` (set when the ID was
  /// uploaded) so an admin can review both photos manually.
  Future<String> uploadSelfie({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const UserAuthException(
        'Your session has expired. Please verify your email again before taking a selfie.',
      );
    }

    final ext = fileExtension.replaceFirst('.', '').toLowerCase();
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path = '$userId/selfie_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}';

    try {
      await Supabase.instance.client.storage.from('identity_docs').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await Supabase.instance.client.from('users').update({
        'selfie_photo_url': path,
      }).eq('id', userId);
    } on StorageException catch (e) {
      throw UserAuthException('Could not upload your selfie: ${e.message}');
    } on PostgrestException catch (e) {
      throw UserAuthException('Could not save your selfie details: ${e.message}');
    }

    return path;
  }

  Future<void> logout() async {
    UserSession.instance.signOut();
    await Supabase.instance.client.auth.signOut();
  }
}
