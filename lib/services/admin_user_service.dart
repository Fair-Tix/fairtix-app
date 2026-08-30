import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user_summary.dart';

/// Thrown when an admin data-management action (fetching users, signing a
/// document URL, approving/rejecting, suspending) fails.
class AdminUserServiceException implements Exception {
  final String message;
  const AdminUserServiceException(this.message);
}

/// Backs the two admin review screens — `admin-accounts.dart` (all users)
/// and `admin-organizer-applications.dart` (organizers only) — with real
/// Supabase reads/writes.
///
/// Every method here relies on the caller already being signed in as an
/// admin: `users_select_own_or_admin` / `users_update_own_or_admin` in
/// supabase/policies.sql are what actually let these queries see and
/// modify *other* people's rows — a non-admin session would just get its
/// own row back (or a permission-denied on update), RLS enforces that
/// server-side regardless of what this class does.
class AdminUserService {
  AdminUserService._();
  static final AdminUserService instance = AdminUserService._();

  /// Fetches all `public.users` rows, optionally filtered to one [role]
  /// ('buyer' | 'organizer' | 'admin'), newest first.
  Future<List<AdminUserSummary>> fetchUsers({String? role}) async {
    try {
      final query = Supabase.instance.client.from('users').select();
      final rows = await (role != null ? query.eq('role', role) : query)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => AdminUserSummary.fromRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminUserServiceException('Could not load accounts: ${e.message}');
    }
  }

  /// Generates a short-lived signed URL for a file in a private Storage
  /// bucket ('identity_docs' or 'organizer_docs') so an admin can view it
  /// in the review dialog — direct public URLs don't work since both
  /// buckets are private (see supabase/policies.sql).
  Future<String> getSignedUrl(
    String bucket,
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);
    } on StorageException catch (e) {
      throw AdminUserServiceException('Could not load that document: ${e.message}');
    }
  }

  /// Approves or rejects a pending ID/document submission by setting
  /// `id_verification_status` to 'verified' or 'rejected'. Used for both
  /// eventgoer ID+selfie review and organizer proof-of-org review — the
  /// column is shared (see supabase/schema.sql, Table 6).
  Future<void> setIdVerificationStatus({
    required String userId,
    required String status,
  }) async {
    assert(status == 'verified' || status == 'rejected' || status == 'pending');
    try {
      await Supabase.instance.client
          .from('users')
          .update({'id_verification_status': status})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw AdminUserServiceException('Could not update verification status: ${e.message}');
    }
  }

  /// Suspends or reactivates an account by setting `account_status`.
  Future<void> setAccountStatus({
    required String userId,
    required String status,
  }) async {
    assert(status == 'active' || status == 'suspended' || status == 'deactivated');
    try {
      await Supabase.instance.client
          .from('users')
          .update({'account_status': status})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw AdminUserServiceException('Could not update account status: ${e.message}');
    }
  }
}
