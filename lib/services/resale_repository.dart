import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when listing or cancelling a resale listing fails. [message] is
/// safe to show to the user as-is.
class ResaleException implements Exception {
  final String message;
  const ResaleException(this.message);
}

/// Creates and cancels the signed-in user's own resale listings through the
/// `list_ticket_for_resale` / `cancel_resale_listing` database functions
/// (see supabase/resale_functions.sql).
///
/// The rules (ticket ownership, valid/unused ticket, 24-hour cutoff, the
/// 50%-100% price band) are enforced inside those functions, not here: the
/// app can't write to `resale_listings` or `tickets` directly, so a
/// modified client can't skip them. Their rejection messages are plain
/// sentences, which is why they're passed straight through to the user.
class ResaleRepository {
  ResaleRepository._();
  static final ResaleRepository instance = ResaleRepository._();

  /// Lists [ticketId] on the resale market at [price]. On success the
  /// ticket's status becomes `listed` in the database.
  Future<void> listTicket({required String ticketId, required double price}) {
    return _call('list_ticket_for_resale', {
      'p_ticket_id': ticketId,
      'p_price': price,
    });
  }

  /// Takes [ticketId] off the market, returning it to `valid`.
  Future<void> cancelListing({required String ticketId}) {
    return _call('cancel_resale_listing', {'p_ticket_id': ticketId});
  }

  Future<void> _call(String function, Map<String, dynamic> params) async {
    try {
      await Supabase.instance.client.rpc(function, params: params);
    } on PostgrestException catch (e) {
      // PGRST202: the function doesn't exist yet (resale_functions.sql
      // hasn't been run on this Supabase project).
      if (e.code == 'PGRST202') {
        throw const ResaleException('Resale isn\u2019t set up on the server yet.');
      }
      throw ResaleException(e.message);
    } catch (_) {
      throw const ResaleException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }
}
