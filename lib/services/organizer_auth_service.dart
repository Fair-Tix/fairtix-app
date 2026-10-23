import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organizer.dart';
import 'account_status.dart';
import 'organizer_session.dart';
import 'push_service.dart';

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

    final accountStatus = (row['account_status'] as String?) ?? 'active';
    if (accountStatus != 'active') {
      await Supabase.instance.client.auth.signOut();
      throw OrganizerAuthException(inactiveAccountMessage(accountStatus));
    }

    if (row['role'] != 'organizer') {
      await Supabase.instance.client.auth.signOut();
      throw const OrganizerAuthException(
        'This account is not registered as an organizer. Use the eventgoer '
        'app to sign in instead, or apply for an organizer account below.',
      );
    }

    final account = await _buildAccount(
      userId: authUser.id,
      row: row,
      fallbackEmail: normalizedEmail,
    );
    OrganizerSession.instance.signIn(account);
    // Push is best-effort (and a no-op on web); never delays or breaks login.
    unawaited(PushService.instance.registerForCurrentUser());
    return account;
  }

  /// Rehydrates [OrganizerSession] from Supabase's persisted auth session
  /// after a browser refresh, so the organizer stays signed in until they
  /// press Log Out. Returns the restored account, or null when there is no
  /// saved session or it doesn't belong to an active organizer.
  ///
  /// A temporary failure (network, expired token mid-refresh) does NOT sign
  /// the Supabase session out: the organizer just lands on the splash screen
  /// and a later refresh can restore them.
  Future<OrganizerAccount?> restoreSession() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      OrganizerSession.instance.signOut();
      return null;
    }

    try {
      final row = await client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (row == null || row['role'] != 'organizer') {
        OrganizerSession.instance.signOut();
        return null;
      }

      final accountStatus = (row['account_status'] as String?) ?? 'active';
      if (accountStatus != 'active') {
        OrganizerSession.instance.signOut();
        await client.auth.signOut();
        return null;
      }

      final account = await _buildAccount(
        userId: authUser.id,
        row: row,
        fallbackEmail: authUser.email ?? '',
      );
      OrganizerSession.instance.signIn(account);
      unawaited(PushService.instance.registerForCurrentUser());
      return account;
    } on PostgrestException {
      OrganizerSession.instance.signOut();
      return null;
    }
  }

  /// Builds an [OrganizerAccount] from a `public.users` row plus the
  /// organizer's latest active subscription. Shared by [login] and
  /// [restoreSession] so both produce identical accounts.
  Future<OrganizerAccount> _buildAccount({
    required String userId,
    required Map<String, dynamic> row,
    required String fallbackEmail,
  }) async {
    String? subscriptionPlan;
    double? subscriptionFeeRate;
    DateTime? subscriptionRenewsAt;
    bool subscriptionCanExport = false;
    DateTime? subscriptionExpiredAt;
    try {
      // Only a subscription that has not run out counts. This is the same
      // rule the server uses for plan limits (current_date between start_date
      // and end_date, in UTC), so an expired organizer lands on the plan
      // screen to renew through PayMongo instead of looking subscribed.
      final today = DateTime.now().toUtc().toIso8601String().split('T').first;
      final subRow = await Supabase.instance.client
          .from('organizer_subscriptions')
          .select('*, subscription_plans(name, can_export, platform_fee_rate)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', today)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (subRow != null) {
        // The plan the organizer actually paid for (plan_id, set by
        // fulfill_organizer_subscription). Matching by fee is only the
        // fallback for old rows with no plan_id: fees are admin-editable now,
        // so a fee match alone can no longer be trusted.
        final paidPlan = subRow['subscription_plans'];
        subscriptionPlan =
            (paidPlan is Map ? paidPlan['name'] as String? : null) ??
            planNameFromMonthlyFee(subRow['monthly_fee'] as num?);
        // Same rule as the server's organizer_can_export(): the plan's export
        // switch, or (for an old row with no plan) a fee of 699 or more.
        subscriptionCanExport =
            (paidPlan is Map ? paidPlan['can_export'] as bool? : null) ??
            ((subRow['monthly_fee'] as num?) ?? 0) >= 699;
        // The plan's own fee rate, as the admin last saved it. Null for an old
        // row with no linked plan: the report then shows the fee as unknown
        // instead of guessing a rate.
        subscriptionFeeRate = (paidPlan is Map
                ? paidPlan['platform_fee_rate'] as num?
                : null)
            ?.toDouble();
        final endDate = subRow['end_date'] as String?;
        subscriptionRenewsAt = endDate != null
            ? DateTime.tryParse(endDate)
            : null;
      } else {
        // No current plan. If they had one that ran out, remember when so the
        // app can say "expired on <date>" and keep subscription features
        // locked until they renew. This never blocks login.
        try {
          final expiredRow = await Supabase.instance.client
              .from('organizer_subscriptions')
              .select('end_date')
              .eq('user_id', userId)
              .inFilter('status', ['active', 'expired'])
              .order('end_date', ascending: false)
              .limit(1)
              .maybeSingle();
          final expiredEnd = expiredRow?['end_date'] as String?;
          if (expiredEnd != null) {
            subscriptionExpiredAt = DateTime.tryParse(expiredEnd);
          }
        } on PostgrestException {
          // Non-fatal: the organizer is simply treated as having no plan.
        }
      }
    } on PostgrestException {
      // Non-fatal: the organizer just hasn't picked (or synced) a plan yet;
      // subscriptionPlan stays null and the login flow will send them to
      // OrganizerSubscriptionPlanScreen.
    }

    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    final organizationName =
        (row['organization_name'] as String?)?.trim() ?? '';
    return OrganizerAccount(
      id: userId,
      fullName: fullName.isNotEmpty ? fullName : 'Organizer',
      email: (row['email'] as String?) ?? fallbackEmail,
      organizationName: organizationName.isNotEmpty
          ? organizationName
          : 'Your Organization',
      subscriptionPlan: subscriptionPlan,
      subscriptionFeeRate: subscriptionFeeRate,
      subscriptionRenewsAt: subscriptionRenewsAt,
      subscriptionCanExport: subscriptionCanExport,
      idVerificationStatus:
          (row['id_verification_status'] as String?) ?? 'pending',
      venueProofUrl: row['venue_proof_url'] as String?,
      eventPermitUrl: row['event_permit_url'] as String?,
      subscriptionExpiredAt: subscriptionExpiredAt,
    );
  }

  /// Re-reads the signed-in organizer's account from the server and updates
  /// [OrganizerSession], so an admin approval or a renewed subscription takes
  /// effect without logging out. Returns the fresh account, or null when it
  /// can't be loaded (offline, signed out); callers should then keep using
  /// the account already in the session.
  Future<OrganizerAccount?> refreshAccount() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final row = await client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (row == null || row['role'] != 'organizer') return null;
      final account = await _buildAccount(
        userId: authUser.id,
        row: row,
        fallbackEmail: authUser.email ?? '',
      );
      OrganizerSession.instance.updateAccount(account);
      return account;
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Removed: a plan can no longer be written straight from the app. The
  /// client write policies on `organizer_subscriptions` are dropped
  /// (supabase/organizer_subscription_payment.sql); a plan is only activated
  /// after PayMongo confirms payment. Use
  /// `OrganizerSubscriptionService.startCheckout` / `confirmPayment`.
  @Deprecated(
    'Plans are paid through PayMongo: use OrganizerSubscriptionService.',
  )
  Future<void> selectSubscriptionPlan({
    required String planName,
    required DateTime renewsAt,
  }) async {
    throw const OrganizerAuthException(
      'Plans must be purchased through PayMongo.',
    );
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
      final user = response.user;
      if (user == null) {
        throw const OrganizerAuthException(
          'Could not create your account. Please try again.',
        );
      }
      // Supabase returns an obfuscated user with empty `identities` (no
      // error) when the email already belongs to a confirmed account.
      if (user.identities != null && user.identities!.isEmpty) {
        throw const OrganizerAuthException(
          'An account with this email already exists. Try logging in instead.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        throw const OrganizerAuthException(
          'An account with this email already exists. Try logging in instead.',
        );
      }
      throw OrganizerAuthException(e.message);
    }
  }

  /// Confirms the 6-digit code from Supabase's "Confirm signup" email,
  /// completing organizer registration and creating a session. Same flow as
  /// the eventgoer's `UserAuthService.verifyRegistrationOtp`; the session it
  /// creates is what lets the proof-of-organization documents be uploaded
  /// right after (Storage RLS requires an authenticated user).
  ///
  /// The Supabase "Confirm signup" email template must use `{{ .Token }}`
  /// (not `{{ .ConfirmationURL }}`) for this to be a code instead of a link.
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        token: token.trim(),
      );
    } on AuthException catch (e) {
      throw OrganizerAuthException(e.message);
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
      throw OrganizerAuthException(e.message);
    }
  }

  void logout() {
    // Stop listening for this account's notifications. Fire-and-forget so
    // logging out stays instant, exactly as before.
    unawaited(PushService.instance.unregister());
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
