import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Thrown when loading the signed-in user's transaction history fails.
class TransactionRepositoryException implements Exception {
  final String message;
  const TransactionRepositoryException(this.message);
}

/// The signed-in user's full transaction history — ticket purchases,
/// resale purchases, resale sales and refunds — loaded through the
/// `get_my_transactions()` Postgres function (see
/// supabase/my_transactions.sql). It is a SECURITY DEFINER function
/// because `tickets` RLS only lets the current owner read a ticket, so a
/// plain joined query would drop a user's rows once a ticket was resold.
/// Refunds live in `public.refunds` and are merged in by the function.
///
/// Screens call [refresh] once (e.g. in `initState`) to pull the latest
/// rows into a local cache, then read the synchronous [transactions]
/// getter to render — same pattern as PublicEventRepository / EventRepository.
class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  List<AppTransaction> _transactions = [];

  List<AppTransaction> get transactions => List.unmodifiable(_transactions);

  /// Fetches every transaction, resale and refund involving the signed-in
  /// user (most recent first) and replaces the local cache. Silently
  /// empties the cache if nobody is signed in.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _transactions = [];
      return;
    }

    try {
      final rows = await Supabase.instance.client.rpc('get_my_transactions') as List;

      _transactions = rows
          .map((row) => AppTransaction.fromRow(row as Map<String, dynamic>, currentUserId: userId))
          .toList();
    } on PostgrestException catch (e) {
      throw TransactionRepositoryException('Could not load your transactions: ${e.message}');
    }
  }
}
