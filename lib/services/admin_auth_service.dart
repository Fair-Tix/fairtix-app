import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_session.dart';

/// thrown when an admin login attempt fails
class AdminAuthException implements Exception {
  final String message;
  const AdminAuthException(this.message);
}

/// Handles admin authentication for the portal.
///
/// [login] calls `supabase.auth.signInWithPassword(...)`, then confirms
/// the account's `public.users.role` is 'admin' before letting the
/// session through — anyone else (buyer/organizer credentials, or no
/// account at all) is rejected and signed back out.
///
/// There is deliberately no `register()` here: per
/// docs/FairTix-Backend-Roadmap.md (Phase 1), admin accounts are not
/// self-registered. They're pre-seeded directly in the Supabase
/// Dashboard (Authentication → Add user), then promoted to
/// `role = 'admin'` on their `public.users` row via the SQL Editor —
/// RLS blocks any client-side self-promotion by design (see
/// `users_update_own_or_admin` in supabase/policies.sql).
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  /// Shown on the login screen so testers know what to type. Left empty
  /// now that [login] hits real Supabase Auth — there's no local test
  /// account anymore; sign in with a Supabase-seeded admin account.
  static const String debugCredentialsHint = '';

  Future<void> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();

    AuthResponse response;
    try {
      response = await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw AdminAuthException(e.message);
    }

    final authUser = response.user;
    if (authUser == null) {
      throw const AdminAuthException(
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
      throw AdminAuthException('Could not load your account details: ${e.message}');
    }

    if (row['role'] != 'admin') {
      await Supabase.instance.client.auth.signOut();
      throw const AdminAuthException(
        'This account does not have admin access. This portal is restricted '
        'to authorized FairTix personnel only.',
      );
    }

    AdminSession.instance.signIn(
      (row['email'] as String?) ?? normalizedEmail,
      memberSince: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }

  void logout() {
    AdminSession.instance.signOut();
    Supabase.instance.client.auth.signOut();
  }
}
