import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket.dart';
import 'user_session.dart';

/// Thrown when loading the signed-in user's tickets fails.
class TicketRepositoryException implements Exception {
  final String message;
  const TicketRepositoryException(this.message);
}

/// The signed-in buyer's own tickets, backed by `public.tickets` joined
/// through `public.ticket_tiers` / `public.events` (see
/// supabase/schema.sql), plus any active `public.resale_listings` price
/// for tickets currently listed for resale.
///
/// Screens call [refresh] once (e.g. in `initState`) to pull the latest
/// rows into a local cache, then read the synchronous [tickets] getter to
/// render — same pattern as PublicEventRepository / EventRepository.
///
/// This cache also backs the one-ticket-per-account-per-event purchase
/// limit check (see [userOwnsTicketForEvent] in data/sample_tickets.dart),
/// so keeping it reasonably fresh (refreshed after every purchase, and
/// whenever My Tickets or an event's details are opened) matters beyond
/// just the My Tickets screen itself.
class TicketRepository {
  TicketRepository._();
  static final TicketRepository instance = TicketRepository._();

  List<Ticket> _tickets = [];

  List<Ticket> get tickets => List.unmodifiable(_tickets);

  /// Fetches every ticket owned by the signed-in user (most recently
  /// purchased first) and replaces the local cache. Silently empties the
  /// cache if nobody is signed in, rather than throwing.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _tickets = [];
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('tickets')
          .select('''
            ticket_id, qr_code_token, qr_status, ticket_status,
            purchase_price, service_fee, purchased_at, used_at,
            ticket_tiers!inner(
              tier_id, tier_name, base_price, event_id,
              events!inner(event_id, title, venue, event_start_date, event_end_date, event_type)
            )
          ''')
          .eq('owner_id', userId)
          .order('purchased_at', ascending: false) as List;

      final ticketIds = rows.map((r) => r['ticket_id'] as String).toList();

      // Active resale listing price per ticket, if any — a ticket only
      // shows a resale price while it currently has an active listing.
      final resalePriceByTicket = <String, double>{};
      if (ticketIds.isNotEmpty) {
        final listingRows = await Supabase.instance.client
            .from('resale_listings')
            .select('ticket_id, listing_price')
            .inFilter('ticket_id', ticketIds)
            .eq('listing_status', 'active') as List;
        for (final row in listingRows) {
          resalePriceByTicket[row['ticket_id'] as String] = (row['listing_price'] as num).toDouble();
        }
      }

      final ownerName = UserSession.instance.account?.fullName ?? 'FairTix User';
      _tickets = rows
          .map((row) => Ticket.fromRow(
                row as Map<String, dynamic>,
                ownerName: ownerName,
                resalePrice: resalePriceByTicket[row['ticket_id']],
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw TicketRepositoryException('Could not load your tickets: ${e.message}');
    }
  }

  Ticket? getById(String id) {
    for (final ticket in _tickets) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }
}
