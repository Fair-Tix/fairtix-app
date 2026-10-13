import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';

/// Thrown when loading the public event catalogue fails.
class PublicEventRepositoryException implements Exception {
  final String message;
  const PublicEventRepositoryException(this.message);
}

/// The published event catalogue shown to eventgoers (Dashboard, All
/// Events, Event Details), backed by `public.events` / `public.ticket_tiers`
/// (see supabase/schema.sql).
///
/// Screens call [refresh] once (e.g. in `initState`) to pull the latest
/// published events into a local cache, then read the synchronous [events]
/// getter to render.
class PublicEventRepository {
  PublicEventRepository._();
  static final PublicEventRepository instance = PublicEventRepository._();

  List<EventSummary> _events = [];

  List<EventSummary> get events => List.unmodifiable(_events);

  /// A small fixed palette so each event gets a stable-looking accent
  /// color (there's no `accent_color` column in `public.events` — the
  /// database only stores a banner image path). The same event id always
  /// maps to the same color for the lifetime of the app run.
  static const List<Color> _palette = [
    Color(0xFF7C3AED), // purple
    Color(0xFF2563EB), // blue
    Color(0xFFDB2777), // pink
    Color(0xFF059669), // green
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
    Color(0xFF0891B2), // cyan
  ];

  Color _colorForEvent(String eventId) {
    final index = eventId.hashCode.abs() % _palette.length;
    return _palette[index];
  }

  /// Fetches every top-level (non-child) published event, plus each
  /// event's ticket tiers, and replaces the local cache. Only events with
  /// `status == 'published'` are shown to eventgoers — draft/cancelled/
  /// completed events are excluded, matching the buyer-facing catalogue.
  Future<void> refresh() async {
    try {
      final eventRows =
          await Supabase.instance.client
                  .from('events')
                  .select()
                  .eq('status', 'published')
                  .isFilter('parent_event_id', null)
                  .order('event_start_date', ascending: true)
              as List;

      final eventIds = eventRows.map((row) => row['event_id'] as String).toList();

      final tiersByEvent = <String, List<TicketTier>>{};
      if (eventIds.isNotEmpty) {
        final tierRows =
            await Supabase.instance.client
                    .from('ticket_tiers')
                    .select()
                    .inFilter('event_id', eventIds)
                    .order('base_price', ascending: true)
                as List;
        for (final row in tierRows) {
          final eventId = row['event_id'] as String;
          tiersByEvent.putIfAbsent(eventId, () => []).add(_tierFromRow(row as Map<String, dynamic>));
        }
      }

      _events = eventRows
          .map((row) => _eventFromRow(row as Map<String, dynamic>, tiersByEvent))
          .toList();
    } on PostgrestException catch (e) {
      throw PublicEventRepositoryException('Could not load events: ${e.message}');
    }
  }

  EventSummary? getById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  TicketTier _tierFromRow(Map<String, dynamic> row) {
    return TicketTier(
      id: row['tier_id'] as String,
      name: row['tier_name'] as String,
      seatingLabel: 'General Admission',
      price: (row['base_price'] as num).toDouble(),
      remainingQuantity: row['remaining_quantity'] as int?,
    );
  }

  EventSummary _eventFromRow(
    Map<String, dynamic> row,
    Map<String, List<TicketTier>> tiersByEvent,
  ) {
    final eventId = row['event_id'] as String;
    final startDate = DateTime.parse(row['event_start_date'] as String);
    final endDateRaw = row['event_end_date'] as String?;
    final isMulti = row['event_type'] == 'multi_day';
    final dateLabel = isMulti && endDateRaw != null
        ? '${_formatDate(startDate)} \u2013 ${_formatDate(DateTime.parse(endDateRaw))}'
        : _formatDate(startDate);
    final tiers = tiersByEvent[eventId] ?? const [];
    final cheapest = tiers.isEmpty
        ? null
        : tiers.reduce((a, b) => a.price < b.price ? a : b);

    return EventSummary(
      id: eventId,
      title: row['title'] as String,
      venue: row['venue'] as String,
      dateLabel: dateLabel,
      eventDateTime: startDate,
      priceLabel: cheapest == null ? 'TBA' : formatPeso(withPlatformFee(cheapest.price, kPrimaryPlatformFeeRate)),
      accentColor: _colorForEvent(eventId),
      description: row['description'] as String?,
      tiers: tiers,
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
