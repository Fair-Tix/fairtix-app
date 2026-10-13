import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Thrown when loading the signed-in user's transaction history fails.
class TransactionRepositoryException implements Exception {
  final String message;
  const TransactionRepositoryException(this.message);
}

/// The signed-in user's transaction history — every payment they've made
/// or received (ticket purchases, resale purchases, resale sales) —
/// backed by `public.transactions` joined through `public.tickets` /
/// `public.ticket_tiers` / `public.events` (see supabase/schema.sql).
///
/// Screens call [refresh] once (e.g. in `initState`) to pull the latest
/// rows into a local cache, then read the synchronous [transactions]
/// getter to render — same pattern as PublicEventRepository / EventRepository.
class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  List<AppTransaction> _transactions = [];

  List<AppTransaction> get transactions => List.unmodifiable(_transactions);

  /// Fetches every transaction where the signed-in user is either the
  /// buyer or the seller (most recent first) and replaces the local
  /// cache. Silently empties the cache if nobody is signed in.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _transactions = [];
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('transactions')
          .select('''
            transaction_id, ticket_id, buyer_id, seller_id, transaction_type,
            amount, platform_fee, status, created_at,
            tickets!inner(
              ticket_tiers!inner(
                tier_name,
                events!inner(title)
              )
            )
          ''')
          .or('buyer_id.eq.$userId,seller_id.eq.$userId')
          .order('created_at', ascending: false) as List;

      _transactions = rows
          .map((row) => AppTransaction.fromRow(row as Map<String, dynamic>, currentUserId: userId))
          .toList();
    } on PostgrestException catch (e) {
      throw TransactionRepositoryException('Could not load your transactions: ${e.message}');
    }
  }
}
