import 'event.dart';

/// Lifecycle state of an owned ticket instance.
/// Mirrors the `ticket_status` enum in the TICKETS Firestore collection
/// (valid / used / listed / canceled) — "used" and "canceled" are omitted
/// here since this prototype UI only needs to distinguish tickets that can
/// still be listed for resale from ones that already are.
enum TicketStatus { valid, listed, used }

/// Placeholder "ticket the current user owns" model for UI scaffolding.
/// TODO: replace with the real TICKETS Firestore document (qr_code_token,
/// qr_status, owner_id, etc.) once the backend is wired up.
class Ticket {
  const Ticket({
    required this.id,
    required this.event,
    required this.tier,
    required this.ownerName,
    required this.qrToken,
    this.status = TicketStatus.valid,
    this.resalePrice,
  });

  final String id;
  final EventSummary event;
  final TicketTier tier;
  final String ownerName;
  final String qrToken;
  final TicketStatus status;

  /// Set once the ticket has an active RESALE_LISTINGS record.
  /// Mirrors `resale_listings.listing_price` for this ticket.
  final double? resalePrice;

  /// System-enforced resale floor: 50% of the original purchase price.
  double get minResalePrice => tier.price * 0.5;

  /// System-enforced resale ceiling: 100% of the original purchase price.
  double get maxResalePrice => tier.price;

  Ticket copyWith({TicketStatus? status, double? resalePrice}) {
    return Ticket(
      id: id,
      event: event,
      tier: tier,
      ownerName: ownerName,
      qrToken: qrToken,
      status: status ?? this.status,
      resalePrice: resalePrice ?? this.resalePrice,
    );
  }
}
