import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the escrow overview cannot be loaded.
class OrganizerEscrowException implements Exception {
  final String message;
  const OrganizerEscrowException(this.message);
}

/// What happens to an event's money, for the status chip on the Escrow screen.
enum EscrowStage { noSales, held, partiallyReleased, released, refunded }

/// One event's escrow position. All amounts are the ORGANIZER'S share (ticket
/// price minus FairTix's platform fee), except [refunded] which is what buyers
/// got back.
class EscrowEventRow {
  final String eventId;
  final String title;
  final String eventStatus;
  final DateTime? startDate;
  final DateTime? endDate;

  /// The day escrow is released: the day after the event's last day (Manila).
  final DateTime? releaseDate;
  final int ticketsSold;
  final int refundedTickets;
  final double gross;
  final double fees;
  final double net;
  final double held;
  final double released;
  final double refunded;

  const EscrowEventRow({
    required this.eventId,
    required this.title,
    required this.eventStatus,
    required this.startDate,
    required this.endDate,
    required this.releaseDate,
    required this.ticketsSold,
    required this.refundedTickets,
    required this.gross,
    required this.fees,
    required this.net,
    required this.held,
    required this.released,
    required this.refunded,
  });

  factory EscrowEventRow.fromRow(Map<String, dynamic> row) {
    double money(String key) => (row[key] as num?)?.toDouble() ?? 0;
    DateTime? date(String key) =>
        row[key] == null ? null : DateTime.tryParse('${row[key]}');
    return EscrowEventRow(
      eventId: '${row['event_id']}',
      title: (row['event_title'] as String?) ?? 'Untitled event',
      eventStatus: (row['event_status'] as String?) ?? '',
      startDate: date('event_start_date'),
      endDate: date('event_end_date'),
      releaseDate: date('release_date'),
      ticketsSold: (row['tickets_sold'] as num?)?.toInt() ?? 0,
      refundedTickets: (row['refunded_tickets'] as num?)?.toInt() ?? 0,
      gross: money('gross_amount'),
      fees: money('platform_fees'),
      net: money('net_amount'),
      held: money('escrow_held'),
      released: money('escrow_released'),
      refunded: money('refunded_amount'),
    );
  }

  EscrowStage get stage {
    if (held > 0 && released > 0) return EscrowStage.partiallyReleased;
    if (held > 0) return EscrowStage.held;
    if (released > 0) return EscrowStage.released;
    if (refunded > 0) return EscrowStage.refunded;
    return EscrowStage.noSales;
  }
}

/// All of the organizer's events plus the totals shown at the top.
class EscrowOverview {
  final List<EscrowEventRow> events;

  const EscrowOverview(this.events);

  double get totalHeld => events.fold(0.0, (sum, e) => sum + e.held);
  double get totalReleased => events.fold(0.0, (sum, e) => sum + e.released);
  double get totalRefunded => events.fold(0.0, (sum, e) => sum + e.refunded);

  /// The next day any held money is released (earliest upcoming release date
  /// among events that still hold escrow), or null when nothing is held.
  DateTime? get nextRelease {
    DateTime? next;
    for (final e in events) {
      final date = e.releaseDate;
      if (e.held > 0 && date != null && (next == null || date.isBefore(next))) {
        next = date;
      }
    }
    return next;
  }
}

/// Reads the organizer's escrow position
/// (`organizer_escrow_overview`, supabase/organizer_escrow.sql).
///
/// The rule: a buyer's payment is held in escrow, and is released to the
/// organizer once the event's schedule date is over. Release happens in the
/// database (`complete_finished_events`), never from the app.
class OrganizerEscrowService {
  OrganizerEscrowService._();
  static final OrganizerEscrowService instance = OrganizerEscrowService._();

  Future<EscrowOverview> fetch() async {
    final client = Supabase.instance.client;

    // Make sure events that have just ended are completed (and their escrow
    // released) before reading, so the screen never lags behind the daily job.
    // Best effort: a failure here must not hide the overview.
    try {
      await client.rpc('complete_finished_events');
    } catch (_) {}

    try {
      final rows = await client.rpc('organizer_escrow_overview') as List;
      return EscrowOverview([
        for (final row in rows.cast<Map<String, dynamic>>())
          EscrowEventRow.fromRow(row),
      ]);
    } on PostgrestException catch (e) {
      // PGRST202 = function missing: the SQL file has not been run yet.
      if (e.code == 'PGRST202') {
        throw const OrganizerEscrowException(
          'Escrow is not set up yet: run supabase/organizer_escrow.sql in the '
          'Supabase SQL Editor first.',
        );
      }
      throw OrganizerEscrowException('Could not load escrow: ${e.message}');
    }
  }
}
