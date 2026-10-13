import 'package:flutter/material.dart';

import 'event.dart';

/// Lifecycle state of an owned ticket instance.
/// Mirrors the `ticket_status` enum in `public.tickets` (see
/// supabase/schema.sql) — 'canceled' is folded into [used] here since this
/// UI only needs to distinguish tickets that can still be listed for
/// resale from ones that can't.
enum TicketStatus { valid, listed, used }

TicketStatus _statusFromRow(String raw) => switch (raw) {
      'listed' => TicketStatus.listed,
      'valid' => TicketStatus.valid,
      _ => TicketStatus.used, // 'used' or 'canceled'
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
      priceLabel: formatPeso(withPlatformFee(tier.price, kPrimaryPlatformFeeRate)),
      accentColor: _colorForId(eventRow['event_id'] as String),
    );

    return Ticket(
      id: row['ticket_id'] as String,
      event: event,
      tier: tier,
      ownerName: ownerName,
      qrToken: row['qr_code_token'] as String,
      status: resalePrice != null ? TicketStatus.listed : _statusFromRow(row['ticket_status'] as String),
      resalePrice: resalePrice,
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
