import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket.dart';
import 'ticket_cache.dart';
import 'user_session.dart';

/// Thrown when loading the signed-in user's tickets fails.
class TicketRepositoryException implements Exception {
  final String message;
  const TicketRepositoryException(this.message);
}

typedef _FetchResult = ({List<Map<String, dynamic>> rows, Map<String, double> resalePrices});

/// The signed-in buyer's own tickets, backed by `public.tickets` joined
/// through `public.ticket_tiers` / `public.events` (see
/// supabase/schema.sql), plus any active `public.resale_listings` price
/// for tickets currently listed for resale.
///
/// Screens call [refresh] once (e.g. in `initState`) to pull the latest
/// rows into a local cache, then read the synchronous [tickets] getter to
/// render — same pattern as PublicEventRepository / EventRepository.
///
/// Offline support: every successful [refresh] also saves a snapshot to
/// encrypted device storage (see [TicketCache]). If a later [refresh]
/// can't reach the server (no connection, or it times out), the saved
/// snapshot is loaded instead and [isFromCache] becomes true, so the
/// wallet and each ticket's QR code stay viewable offline. Real server
/// errors (a rejected query, an RLS problem) are NOT papered over by the
/// snapshot — they still throw, so bugs stay visible.
///
/// This cache also backs the one-ticket-per-account-per-event purchase
/// limit check (see [userOwnsTicketForEvent] in data/sample_tickets.dart),
/// so keeping it reasonably fresh (refreshed after every purchase, and
/// whenever My Tickets or an event's details are opened) matters beyond
/// just the My Tickets screen itself.
class TicketRepository {
  TicketRepository._();
  static final TicketRepository instance = TicketRepository._();

  /// How long to wait for the server before assuming we're offline and
  /// using the saved copy. Bad venue signal often hangs rather than fails
  /// fast, so without this the wallet would just spin.
  static const Duration _networkTimeout = Duration(seconds: 10);

  List<Ticket> _tickets = [];
  bool _isFromCache = false;
  DateTime? _lastSyncedAt;

  List<Ticket> get tickets => List.unmodifiable(_tickets);

  /// True when [tickets] came from the saved offline copy rather than a
  /// live fetch, meaning statuses (valid / listed / used) may be out of
  /// date.
  bool get isFromCache => _isFromCache;

  /// When the data currently in [tickets] was last fetched from the
  /// server (for an offline copy, when that copy was saved).
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Fetches every ticket owned by the signed-in user (most recently
  /// purchased first) and replaces the local cache. Silently empties the
  /// cache if nobody is signed in, rather than throwing.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _tickets = [];
      _isFromCache = false;
      _lastSyncedAt = null;
      return;
    }

    final ownerName = UserSession.instance.account?.fullName ?? 'FairTix User';

    // Only the network call is inside the try: a connectivity failure
    // falls back to the saved copy, but a bug while building tickets
    // below should still surface instead of being hidden by stale data.
    _FetchResult? fetched;
    try {
      fetched = await _fetchFromServer(userId).timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      // The server answered and rejected the request. That's a real
      // problem, not "offline", so don't hide it behind stale data.
      throw TicketRepositoryException('Could not load your tickets: ${e.message}');
    } catch (_) {
      // Anything else (SocketException, timeout, auth refresh failing for
      // lack of network, ...) is treated as "can't reach the server".
      fetched = null;
    }

    if (fetched == null) {
      final snapshot = await TicketCache.instance.load(userId);
      if (snapshot == null) {
        throw const TicketRepositoryException(
          'You\u2019re offline and no saved tickets were found. Connect to the internet and open My Tickets once to save them for offline use.',
        );
      }
      _tickets = _buildTickets(
        snapshot.rows,
        snapshot.resalePrices,
        UserSession.instance.account?.fullName ?? snapshot.ownerName,
      );
      _isFromCache = true;
      _lastSyncedAt = snapshot.savedAt;
      return;
    }

    _tickets = _buildTickets(fetched.rows, fetched.resalePrices, ownerName);
    _isFromCache = false;
    _lastSyncedAt = DateTime.now();

    await TicketCache.instance.save(
      userId,
      TicketCacheSnapshot(
        rows: fetched.rows,
        resalePrices: fetched.resalePrices,
        ownerName: ownerName,
        savedAt: _lastSyncedAt!,
      ),
    );
  }

  /// Closes any resale listing whose event is now within 24 hours of
  /// starting (listing -> expired, ticket -> valid again) so the wallet below
  /// never shows a stale "listed" ticket. Done in the database
  /// (supabase/resale_functions.sql); the app just asks for it to run.
  ///
  /// Failures are ignored on purpose: this is housekeeping, and it must never
  /// stop the wallet from loading — e.g. before resale_functions.sql has been
  /// run on this project, or when offline.
  Future<void> _expireDueListings() async {
    try {
      await Supabase.instance.client.rpc('expire_resale_listings');
    } catch (_) {
      // Ignored; see above.
    }
  }

  Future<_FetchResult> _fetchFromServer(
    String userId,
  ) async {
    // Must come first so the ticket query below already sees the result.
    await _expireDueListings();

    final rawRows = await Supabase.instance.client
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

    final rows = rawRows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final ticketIds = rows.map((r) => r['ticket_id'] as String).toList();

    // Active resale listing price per ticket, if any — a ticket only
    // shows a resale price while it currently has an active listing.
    final resalePrices = <String, double>{};
    if (ticketIds.isNotEmpty) {
      final listingRows = await Supabase.instance.client
          .from('resale_listings')
          .select('ticket_id, listing_price')
          .inFilter('ticket_id', ticketIds)
          .eq('listing_status', 'active') as List;
      for (final row in listingRows) {
        resalePrices[row['ticket_id'] as String] = (row['listing_price'] as num).toDouble();
      }
    }

    return (rows: rows, resalePrices: resalePrices);
  }

  List<Ticket> _buildTickets(
    List<Map<String, dynamic>> rows,
    Map<String, double> resalePrices,
    String ownerName,
  ) {
    return rows
        .map((row) => Ticket.fromRow(
              row,
              ownerName: ownerName,
              resalePrice: resalePrices[row['ticket_id']],
            ))
        .toList();
  }

  Ticket? getById(String id) {
    for (final ticket in _tickets) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }

  /// Wipes the in-memory tickets and this user's saved offline copy. Call
  /// on logout so the next person to sign in on this phone never sees (or
  /// can read back) the previous account's tickets.
  Future<void> clearForLogout() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _tickets = [];
    _isFromCache = false;
    _lastSyncedAt = null;
    if (userId != null) {
      await TicketCache.instance.clear(userId);
    }
  }
}
