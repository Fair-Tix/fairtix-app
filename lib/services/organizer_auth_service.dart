import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organizer.dart';
import 'organizer_session.dart';

/// Thrown when an organizer auth action (login, register) fails.
class OrganizerAuthException implements Exception {
  final String message;
  const OrganizerAuthException(this.message);
}

/// Handles organizer authentication.
///
/// [register] is wired to real Supabase Auth. [login] still checks the
/// hardcoded [_testAccount] pending Phase 1's login work (see
/// docs/FairTix-Backend-Roadmap.md) — replace it the same way, with
/// `supabase.auth.signInWithPassword(...)` followed by loading the
/// matching row (joined with the latest `organizer_subscriptions` row)
/// from Postgres into [OrganizerSession].
///
/// Exactly one seeded test account exists so the login -> dashboard ->
/// navigation flow can be exercised end-to-end before real login is wired
/// up. No other sample accounts are created anywhere in the app.
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

  /// Creates a new organizer account in Supabase Auth. A `public.users`
  /// row is auto-created by the `on_auth_user_created` trigger (see
  /// supabase/schema.sql) with `role = 'organizer'` and
  /// `id_verification_status = 'pending'` — the account exists immediately
  /// but stays unable to do organizer-only actions until an admin reviews
  /// it (Phase 6).
  ///
  /// Document uploads (proof of venue booking / event permit) are not yet
  /// wired to Supabase Storage — [organizer-register.dart] still only
  /// simulates the file picker locally. Wiring real uploads to the
  /// `organizer_docs` bucket (see supabase/policies.sql) is a follow-up.
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
  }
}
