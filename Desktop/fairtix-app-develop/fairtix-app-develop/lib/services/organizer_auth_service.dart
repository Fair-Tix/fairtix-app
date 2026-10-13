import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../models/organizer.dart';
import 'organizer_session.dart';

/// Thrown when an organizer auth action (login, register) fails.
class OrganizerAuthException implements Exception {
  final String message;
  const OrganizerAuthException(this.message);
}

/// Handles organizer authentication.
///
/// [register] and [login] are both wired to real Supabase Auth. [login]
/// calls `supabase.auth.signInWithPassword(...)`, confirms the account's
/// `public.users.role` is 'organizer', loads its latest active
/// `public.organizer_subscriptions` row (if any), and populates
/// [OrganizerSession].
class OrganizerAuthService {
  OrganizerAuthService._();
  static final OrganizerAuthService instance = OrganizerAuthService._();

  /// Shown on the login screen so testers know what to type. Left empty
  /// now that [login] hits real Supabase Auth — there's no single shared
  /// test account anymore, each organizer registers their own.
  static const String debugCredentialsHint = '';

  /// Maps `organizer_subscriptions.monthly_fee` back to a plan name.
  /// The table only stores the fee actually charged (see schema.sql,
  /// Table 7), not a separate plan-name column, so this mirrors the
  /// pricing from Chapter III: ₱299 = Basic, ₱699 = Standard,
  /// ₱1,499 = Premium. Falls back to null (unrecognized amount) rather
  /// than guessing.
  static String? planNameFromMonthlyFee(num? fee) {
    switch (fee) {
      case 299:
        return 'Basic';
      case 699:
        return 'Standard';
      case 1499:
        return 'Premium';
      default:
        return null;
    }
  }

  static num? monthlyFeeForPlanName(String planName) {
    switch (planName) {
      case 'Basic':
        return 299;
      case 'Standard':
        return 699;
      case 'Premium':
        return 1499;
      default:
        return null;
    }
  }

  Future<OrganizerAccount> login({
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
      throw OrganizerAuthException(e.message);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const OrganizerAuthException(
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
      await Supabase.instance.client.auth.signOut();
      throw OrganizerAuthException(
        'Could not load your account details: ${e.message}',
      );
    }

    if (row['role'] != 'organizer') {
      await Supabase.instance.client.auth.signOut();
      throw const OrganizerAuthException(
        'This account is not registered as an organizer. Use the eventgoer '
        'app to sign in instead, or apply for an organizer account below.',
      );
    }

    String? subscriptionPlan;
    DateTime? subscriptionRenewsAt;
    try {
      final subRow = await Supabase.instance.client
          .from('organizer_subscriptions')
          .select()
          .eq('user_id', authUser.id)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (subRow != null) {
        subscriptionPlan = planNameFromMonthlyFee(
          subRow['monthly_fee'] as num?,
        );
        final endDate = subRow['end_date'] as String?;
        subscriptionRenewsAt = endDate != null
            ? DateTime.tryParse(endDate)
            : null;
      }
    } on PostgrestException {
      // Non-fatal: the organizer just hasn't picked (or synced) a plan yet;
      // subscriptionPlan stays null and the login flow will send them to
      // OrganizerSubscriptionPlanScreen.
    }

    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    final organizationName =
        (row['organization_name'] as String?)?.trim() ?? '';
    final account = OrganizerAccount(
      id: authUser.id,
      fullName: fullName.isNotEmpty ? fullName : 'Organizer',
      email: (row['email'] as String?) ?? normalizedEmail,
      organizationName: organizationName.isNotEmpty
          ? organizationName
          : 'Your Organization',
      subscriptionPlan: subscriptionPlan,
      subscriptionRenewsAt: subscriptionRenewsAt,
      idVerificationStatus:
          (row['id_verification_status'] as String?) ?? 'pending',
      venueProofUrl: row['venue_proof_url'] as String?,
      eventPermitUrl: row['event_permit_url'] as String?,
    );

    OrganizerSession.instance.signIn(account);
    return account;
  }

  Future<void> selectSubscriptionPlan({
    required String planName,
    required DateTime renewsAt,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizerAuthException(
        'You must be signed in to choose a subscription plan.',
      );
    }

    final monthlyFee = monthlyFeeForPlanName(planName);
    if (monthlyFee == null) {
      throw OrganizerAuthException('Unknown organizer plan: $planName');
    }

    final startDate = DateTime.now();
    final row = {
      'user_id': userId,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': renewsAt.toIso8601String().split('T').first,
      'status': 'active',
      'monthly_fee': monthlyFee,
    };

    try {
      await Supabase.instance.client
          .from('organizer_subscriptions')
          .insert(row);
    } on PostgrestException catch (e) {
      throw OrganizerAuthException(
        'Could not save your subscription plan: ${e.message}',
      );
    }

    final currentAccount = OrganizerSession.instance.account;
    if (currentAccount != null) {
      OrganizerSession.instance.updateAccount(
        currentAccount.copyWith(
          subscriptionPlan: planName,
          subscriptionRenewsAt: renewsAt,
        ),
      );
    }
  }

  /// Creates a new organizer account in Supabase Auth. A `public.users`
  /// row is auto-created by the `on_auth_user_created` trigger (see
  /// supabase/schema.sql) with `role = 'organizer'` and
  /// `id_verification_status = 'pending'` — the account exists immediately
  /// but stays unable to do organizer-only actions until an admin reviews
  /// it (Phase 6).
  ///
  /// Does not itself upload the proof-of-organization documents — see
  /// [uploadOrganizerDocument], which the caller (organizer-register.dart)
  /// invokes right after this succeeds, if [hasActiveSession] is true.
  Future<void> register({
    required String fullName,
    required String organizationName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName.trim(),
          'organization_name': organizationName.trim(),
          'role': 'organizer',
        },
      );
      if (response.user == null) {
        throw const OrganizerAuthException(
          'Could not create your account. Please try again.',
        );
      }
    } on AuthException catch (e) {
      throw OrganizerAuthException(e.message);
    }
  }

  void logout() {
    OrganizerSession.instance.signOut();
    Supabase.instance.client.auth.signOut();
  }

  /// Whether the Supabase client currently holds an authenticated
  /// session for the organizer. `register()` only establishes one
  /// immediately if "Confirm email" is disabled for this Supabase
  /// project; with confirmations enabled (the current setup — see
  /// docs/FairTix-Backend-Roadmap.md), signUp() returns `session: null`
  /// and this stays false until the organizer confirms their email and
  /// logs in. Storage uploads require a session, so callers should check
  /// this before calling [uploadOrganizerDocument].
  bool get hasActiveSession =>
      Supabase.instance.client.auth.currentUser != null;

  /// Uploads a proof-of-organization document ("venue_proof" or
  /// "event_permit") to the private `organizer_docs` Storage bucket (see
  /// supabase/policies.sql) and records the resulting path on the
  /// matching `public.users` column (`venue_proof_url` /
  /// `event_permit_url` — see supabase/schema.sql).
  ///
  /// Requires an active session (see [hasActiveSession]); throws
  /// [OrganizerAuthException] if there isn't one, or if the upload/save
  /// fails.
  Future<String> uploadOrganizerDocument({
    required String docKind,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    assert(docKind == 'venue_proof' || docKind == 'event_permit');

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrganizerAuthException(
        'You need to be signed in to upload documents.',
      );
    }

    final ext = fileExtension.replaceFirst('.', '').toLowerCase();
    final safeExt = ext.isEmpty ? 'pdf' : ext;
    final path =
        '$userId/${docKind}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = safeExt == 'pdf'
        ? 'application/pdf'
        : 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}';
    final column = docKind == 'venue_proof'
        ? 'venue_proof_url'
        : 'event_permit_url';

    try {
      await Supabase.instance.client.storage
          .from('organizer_docs')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await Supabase.instance.client
          .from('users')
          .update({column: path})
          .eq('id', userId);
    } on StorageException catch (e) {
      throw OrganizerAuthException(
        'Could not upload your document: ${e.message}',
      );
    } on PostgrestException catch (e) {
      throw OrganizerAuthException(
        'Could not save your document details: ${e.message}',
      );
    }

    return path;
  }
}
