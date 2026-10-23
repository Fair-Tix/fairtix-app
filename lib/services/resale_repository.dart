import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket.dart';

/// Thrown when a resale action (list, cancel, load the market, buy) fails.
/// [message] is safe to show to the user as-is.
class ResaleException implements Exception {
  final String message;
  const ResaleException(this.message);
}

/// The Resale Market and the signed-in user's own listings, through the
/// `list_ticket_for_resale` / `cancel_resale_listing` / `get_resale_market`
/// database functions (see supabase/resale_functions.sql and
/// supabase/resale_purchase.sql). Buying a listing is NOT here: it goes
/// through PayMongo like a primary purchase (see ResaleCheckoutScreen and
/// supabase/resale_payment.sql).
///
/// The rules (ticket ownership, valid/unused ticket, 24-hour cutoff, the
/// 50%-100% price band, one ticket per account per event day, QR reissue on
/// purchase) are enforced inside those functions, not here: the app can't
/// write to `resale_listings` or `tickets` directly, so a modified client
/// can't skip them. Their rejection messages are plain sentences, which is
/// why they're passed straight through to the user.
class ResaleRepository {
  ResaleRepository._();
  static final ResaleRepository instance = ResaleRepository._();

  /// Lists [ticketId] on the resale market at [price]. On success the
  /// ticket's status becomes `listed` in the database.
  Future<void> listTicket({required String ticketId, required double price}) async {
    await _invoke('list_ticket_for_resale', {
      'p_ticket_id': ticketId,
      'p_price': price,
    });
  }

  /// Takes [ticketId] off the market, returning it to `valid`.
  Future<void> cancelListing({required String ticketId}) async {
    await _invoke('cancel_resale_listing', {'p_ticket_id': ticketId});
  }

  /// Other users' active listings, newest first. Each [Ticket] carries its
  /// [Ticket.listingId]; its [Ticket.qrToken] is empty (the server never
  /// sends another person's QR).
  Future<List<Ticket>> fetchMarket() async {
    final rows = await _invoke('get_resale_market', null) as List;
    return rows
        .map((row) => Ticket.fromMarketRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<dynamic> _invoke(String function, Map<String, dynamic>? params) async {
    try {
      return await Supabase.instance.client.rpc(function, params: params);
    } on PostgrestException catch (e) {
      // PGRST202: the function doesn't exist yet (the matching SQL file
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
