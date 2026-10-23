import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'account_status.dart';
import 'push_service.dart';
import 'ticket_repository.dart';
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

    final accountStatus = (row['account_status'] as String?) ?? 'active';
    if (accountStatus != 'active') {
      await Supabase.instance.client.auth.signOut();
      throw UserAuthException(inactiveAccountMessage(accountStatus));
    }

    final account = AppUser.fromRow(row);
    UserSession.instance.signIn(account);
    await _saveProfileCache(authUser.id, row);
    // Push is best-effort and must never delay or break login.
    unawaited(PushService.instance.registerForCurrentUser());
    return account;
  }

  // --- Offline profile copy -------------------------------------------------
  // A copy of the user's `public.users` row in encrypted device storage, so
  // the app can restore the signed-in session on launch with no connection
  // (the wallet and QR codes are already viewable offline via TicketCache).
  // Keyed per user id and wiped on logout. Storage errors are swallowed: a
  // broken keystore just means no offline restore, never a broken login.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String _profileKey(String userId) => 'profile_cache_v1_$userId';

  Future<void> _saveProfileCache(String userId, Map<String, dynamic> row) async {
    try {
      await _secureStorage.write(key: _profileKey(userId), value: jsonEncode(row));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadProfileCache(String userId) async {
    try {
      final raw = await _secureStorage.read(key: _profileKey(userId));
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearProfileCache(String userId) async {
    try {
      await _secureStorage.delete(key: _profileKey(userId));
    } catch (_) {}
  }

  /// Re-reads the signed-in eventgoer's `public.users` row and updates
  /// [UserSession], so an admin approval takes effect without logging out.
  /// Also (re)establishes the session for someone who has just finished
  /// registration (the email OTP signs them in, but nothing had loaded their
  /// profile yet). Returns null when there is no signed-in eventgoer or the
  /// server can't be reached; callers then keep the account already in the
  /// session.
  Future<AppUser?> refreshAccount() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final row = await client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (row == null) return null;
      final role = row['role'] as String?;
      if (role == 'organizer' || role == 'admin') return null;
      final account = AppUser.fromRow(row);
      UserSession.instance.signIn(account);
      await _saveProfileCache(authUser.id, row);
      return account;
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
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
          'phone': phone.trim(),
          'birth_date':
              '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
        },
      );
      final user = response.user;
      if (user == null) {
        throw const UserAuthException(
          'Could not create your account. Please try again.',
        );
      }
      // With "Confirm email" enabled, Supabase does NOT error when the email
      // already belongs to a confirmed account (to avoid leaking which
      // emails are registered). It returns an obfuscated user whose
      // `identities` list is empty, so we have to detect that ourselves.
      if (user.identities != null && user.identities!.isEmpty) {
        throw const UserAuthException(
          'An account with this email already exists. Try logging in instead.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        throw const UserAuthException(
          'An account with this email already exists. Try logging in instead.',
        );
      }
      // The signup trigger inserts into public.users, so any failure inside
      // it (e.g. a constraint) surfaces as this generic database error.
      if (msg.contains('database error saving new user')) {
        throw const UserAuthException(
          'Could not create your account. Please try again.',
        );
      }
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
      // The OTP creates a session. Start listening for push alerts now so the
      // "account approved" alert can reach the phone while the user waits on
      // the pending screen (login/restore only run later).
      unawaited(PushService.instance.registerForCurrentUser());
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

  /// Turns a stored `profile_photos` path (what [AppUser.profilePhotoUrl]
  /// holds) into a directly-loadable public URL. The bucket is public-read
  /// (see supabase/profile_photo.sql) but Storage uploads only return the
  /// path. Returns null when there is no photo.
  String? profilePhotoPublicUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return Supabase.instance.client.storage.from('profile_photos').getPublicUrl(path);
  }

  /// Uploads [bytes] as the signed-in eventgoer's profile photo to the
  /// public `profile_photos` bucket, records the path on
  /// `public.users.profile_photo_url`, and refreshes [UserSession] so the
  /// profile screen shows it straight away. The previous photo file (if
  /// any) is deleted on a best-effort basis.
  ///
  /// Profile photos are optional: nothing in registration or login
  /// requires one.
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const UserAuthException('Your session has expired. Please log in again.');
    }

    final ext = fileExtension.replaceFirst('.', '').toLowerCase();
    final safeExt = switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}';
    final previousPath = UserSession.instance.account?.profilePhotoUrl;

    try {
      await Supabase.instance.client.storage.from('profile_photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await Supabase.instance.client.from('users').update({
        'profile_photo_url': path,
      }).eq('id', userId);
    } on StorageException catch (e) {
      throw UserAuthException('Could not upload your photo: ${e.message}');
    } on PostgrestException catch (e) {
      throw UserAuthException('Could not save your photo: ${e.message}');
    }

    final current = UserSession.instance.account;
    if (current != null) {
      UserSession.instance.updateAccount(current.copyWith(profilePhotoUrl: path));
    }

    if (previousPath != null && previousPath != path) {
      try {
        await Supabase.instance.client.storage.from('profile_photos').remove([previousPath]);
      } catch (_) {
        // Orphaned old file is harmless; don't fail the upload over it.
      }
    }

    return path;
  }

  /// Removes the profile photo (back to the initials avatar).
  Future<void> removeProfilePhoto() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const UserAuthException('Your session has expired. Please log in again.');
    }
    final previousPath = UserSession.instance.account?.profilePhotoUrl;

    try {
      await Supabase.instance.client.from('users').update({
        'profile_photo_url': null,
      }).eq('id', userId);
    } on PostgrestException catch (e) {
      throw UserAuthException('Could not remove your photo: ${e.message}');
    }

    final current = UserSession.instance.account;
    if (current != null) {
      UserSession.instance.updateAccount(current.copyWith(clearProfilePhoto: true));
    }

    if (previousPath != null) {
      try {
        await Supabase.instance.client.storage.from('profile_photos').remove([previousPath]);
      } catch (_) {
        // Best effort, as above.
      }
    }
  }

  /// Rehydrates [UserSession] from Supabase's persisted auth session when
  /// the app is reopened, so an eventgoer stays signed in until they press
  /// Log Out. Returns the restored account, or null when there is no saved
  /// session or it doesn't belong to an active eventgoer.
  ///
  /// Offline-safe: if the server can't be reached (no connection, or no
  /// answer within [_restoreTimeout]), the profile saved at last login is
  /// used instead, so the user still lands in the app and can open their
  /// saved tickets. A real server rejection is NOT treated as offline. The
  /// Supabase session is never signed out because of a network problem.
  Future<AppUser?> restoreSession() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      UserSession.instance.signOut();
      return null;
    }

    Map<String, dynamic>? row;
    try {
      row = await client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle()
          .timeout(_restoreTimeout);
      if (row != null) await _saveProfileCache(authUser.id, row);
    } on PostgrestException {
      // The server answered and refused: a real problem, not "offline".
      UserSession.instance.signOut();
      return null;
    } catch (_) {
      // Can't reach the server (offline / timeout): use the saved copy.
      row = await _loadProfileCache(authUser.id);
      if (row == null) {
        UserSession.instance.signOut();
        return null;
      }
    }

    // No profile row, or the saved session belongs to an organizer/admin
    // (they use the web panel). Leave that session alone.
    final role = row?['role'] as String?;
    if (row == null || role == 'organizer' || role == 'admin') {
      UserSession.instance.signOut();
      return null;
    }

    final accountStatus = (row['account_status'] as String?) ?? 'active';
    if (accountStatus != 'active') {
      UserSession.instance.signOut();
      await _clearProfileCache(authUser.id);
      await client.auth.signOut();
      return null;
    }

    final account = AppUser.fromRow(row);
    UserSession.instance.signIn(account);
    unawaited(PushService.instance.registerForCurrentUser());
    return account;
  }

  /// How long app startup waits for the server before falling back to the
  /// saved profile. Kept short so a weak venue signal never leaves the
  /// user staring at a blank screen.
  static const Duration _restoreTimeout = Duration(seconds: 6);

  Future<void> logout() async {
    // Must run before signOut(): it needs the current user id to find the
    // saved offline ticket copy to delete.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) await _clearProfileCache(userId);
    await TicketRepository.instance.clearForLogout();
    // Fire-and-forget so a slow connection can never delay logging out.
    unawaited(PushService.instance.unregister());
    UserSession.instance.signOut();
    await Supabase.instance.client.auth.signOut();
  }
}
