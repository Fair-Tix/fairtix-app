import 'package:flutter/material.dart';

import 'event.dart';

/// Lifecycle state of an owned ticket instance.
/// Mirrors the `ticket_status` enum in `public.tickets` (see
/// supabase/schema.sql): valid, listed, used, canceled.
enum TicketStatus { valid, listed, used, canceled }

TicketStatus _statusFromRow(String raw) => switch (raw) {
      'listed' => TicketStatus.listed,
      'valid' => TicketStatus.valid,
      'canceled' => TicketStatus.canceled,
      _ => TicketStatus.used, // 'used', or anything unrecognised
    };

/// A ticket the current user owns, backed by `public.tickets` joined
/// through `public.ticket_tiers` / `public.events` (see
/// services/ticket_repository.dart for the query).
class Ticket {
  const Ticket({
    required this.id,
    required this.event,
    required this.tier,
    required this.ownerName,
    required this.qrToken,
    this.status = TicketStatus.valid,
    this.resalePrice,
    this.purchasePrice,
    this.listingId,
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

  /// `tickets.purchase_price` — what the owner actually paid (before the
  /// platform fee). The server measures the 50%–100% resale band against
  /// this, so the UI does too. Null for tickets built without a database
  /// row, in which case the tier's current price is used.
  final double? purchasePrice;

  /// `resale_listings.listing_id`, set only for a ticket shown in the Resale
  /// Market (see [Ticket.fromMarketRow]). It's what a buyer passes to
  /// `buy_resale_listing`. Null for the signed-in user's own tickets.
  final String? listingId;

  /// The "original price" the resale band is measured against.
  double get originalPrice => purchasePrice ?? tier.price;

  /// System-enforced resale floor: 50% of the original purchase price.
  double get minResalePrice => originalPrice * 0.5;

  /// System-enforced resale ceiling: 100% of the original purchase price.
  double get maxResalePrice => originalPrice;

  Ticket copyWith({TicketStatus? status, double? resalePrice}) {
    return Ticket(
      id: id,
      event: event,
      tier: tier,
      ownerName: ownerName,
      qrToken: qrToken,
      status: status ?? this.status,
      resalePrice: resalePrice ?? this.resalePrice,
      purchasePrice: purchasePrice,
      listingId: listingId,
    );
  }

  /// Builds a [Ticket] from a `public.tickets` row fetched with tier/event
  /// joined in (see TicketRepository.refresh's select string). [ownerName]
  /// comes from the signed-in [UserSession] rather than a join, since a
  /// buyer's own tickets are always their own name. [resalePrice] comes
  /// from a separate `resale_listings` lookup, since a ticket only has one
  /// when it currently has an active listing.
  factory Ticket.fromRow(
    Map<String, dynamic> row, {
    required String ownerName,
    double? resalePrice,
  }) {
    final tierRow = row['ticket_tiers'] as Map<String, dynamic>;
    final eventRow = tierRow['events'] as Map<String, dynamic>;
    final startDate = DateTime.parse(eventRow['event_start_date'] as String);
    final endDateRaw = eventRow['event_end_date'] as String?;
    final isMulti = eventRow['event_type'] == 'multi_day';
    final dateLabel = isMulti && endDateRaw != null
        ? '${_formatShortDate(startDate)} – ${_formatShortDate(DateTime.parse(endDateRaw))}'
        : _formatShortDate(startDate);

    final tier = TicketTier(
      id: tierRow['tier_id'] as String,
      name: tierRow['tier_name'] as String,
      seatingLabel: 'General Admission',
      price: (tierRow['base_price'] as num).toDouble(),
    );

    final event = EventSummary(
      id: eventRow['event_id'] as String,
      title: eventRow['title'] as String,
      venue: eventRow['venue'] as String,
      dateLabel: dateLabel,
      eventDateTime: startDate,
      priceLabel: formatPeso(tier.price),
      accentColor: _colorForId(eventRow['event_id'] as String),
    );

    // The database status is the source of truth. An active listing only
    // upgrades a ticket that is still valid/listed to "listed" (and supplies
    // its price); it must never override a ticket that has since been used
    // or canceled.
    final dbStatus = _statusFromRow(row['ticket_status'] as String);
    final isLive = dbStatus == TicketStatus.valid || dbStatus == TicketStatus.listed;

    return Ticket(
      id: row['ticket_id'] as String,
      event: event,
      tier: tier,
      ownerName: ownerName,
      qrToken: row['qr_code_token'] as String,
      status: (resalePrice != null && isLive) ? TicketStatus.listed : dbStatus,
      resalePrice: resalePrice,
      purchasePrice: (row['purchase_price'] as num?)?.toDouble(),
    );
  }

  /// Builds a [Ticket] for the Resale Market from one row of the
  /// `get_resale_market()` database function (see
  /// supabase/resale_purchase.sql). It is somebody else's ticket, so:
  ///  - [qrToken] is empty on purpose (the server never sends it);
  ///  - [ownerName] is the seller's first name;
  ///  - [id] is the ticket id and [listingId] is what buying needs.
  factory Ticket.fromMarketRow(Map<String, dynamic> row) {
    final startDate = DateTime.parse(row['event_start_date'] as String);
    final endDateRaw = row['event_end_date'] as String?;
    final isMulti = row['event_type'] == 'multi_day';
    final dateLabel = isMulti && endDateRaw != null
        ? '${_formatShortDate(startDate)} – ${_formatShortDate(DateTime.parse(endDateRaw))}'
        : _formatShortDate(startDate);

    final tier = TicketTier(
      id: row['tier_id'] as String,
      name: row['tier_name'] as String,
      seatingLabel: 'General Admission',
      price: (row['tier_price'] as num).toDouble(),
    );

    final event = EventSummary(
      id: row['event_id'] as String,
      title: row['event_title'] as String,
      venue: row['venue'] as String,
      dateLabel: dateLabel,
      eventDateTime: startDate,
      priceLabel: formatPeso(tier.price),
      accentColor: _colorForId(row['event_id'] as String),
    );

    return Ticket(
      id: row['ticket_id'] as String,
      listingId: row['listing_id'] as String,
      event: event,
      tier: tier,
      ownerName: (row['seller_name'] as String?) ?? 'A verified seller',
      qrToken: '',
      status: TicketStatus.listed,
      resalePrice: (row['listing_price'] as num).toDouble(),
      purchasePrice: (row['original_price'] as num?)?.toDouble(),
    );
  }

  static String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static const List<Color> _palette = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFFDB2777),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
  ];

  static Color _colorForId(String id) => _palette[id.hashCode.abs() % _palette.length];
}
