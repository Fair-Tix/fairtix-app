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
/// (see supabase/schema.sql). Also used read-only by the organizer and
/// admin portals' "Browse Events" screen, so every role sees the same
/// catalogue.
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

  /// Fetches every top-level (non-child) published event, the generated
  /// per-day child events of any multi-day ones, and every event's ticket
  /// tiers, and replaces the local cache.
  ///
  /// Only events with `status == 'published'` are shown — draft, canceled
  /// and completed events are excluded, for parents and for each day of a
  /// multi-day event alike. (A canceled day therefore drops out of its
  /// event's day list while the other days stay on sale.)
  Future<void> refresh() async {
    try {
      final client = Supabase.instance.client;

      final parentRows =
          await client
                  .from('events')
                  .select()
                  .eq('status', 'published')
                  .isFilter('parent_event_id', null)
                  .order('event_start_date', ascending: true)
              as List;

      final parentIds = parentRows.map((row) => row['event_id'] as String).toList();

      // Per-day child rows of multi-day events.
      List childRows = const [];
      if (parentIds.isNotEmpty) {
        childRows =
            await client
                    .from('events')
                    .select()
                    .eq('status', 'published')
                    .inFilter('parent_event_id', parentIds)
                    .order('day_number', ascending: true)
                as List;
      }

      final allIds = [
        ...parentIds,
        ...childRows.map((row) => row['event_id'] as String),
      ];

      final tiersByEvent = <String, List<TicketTier>>{};
      if (allIds.isNotEmpty) {
        final tierRows =
            await client
                    .from('ticket_tiers')
                    .select()
                    .inFilter('event_id', allIds)
                    .order('base_price', ascending: true)
                as List;
        for (final row in tierRows) {
          final eventId = row['event_id'] as String;
          tiersByEvent.putIfAbsent(eventId, () => []).add(_tierFromRow(row as Map<String, dynamic>));
        }
      }

      final daysByParent = <String, List<EventSummary>>{};
      for (final row in childRows) {
        final parentId = row['parent_event_id'] as String;
        daysByParent
            .putIfAbsent(parentId, () => [])
            .add(_eventFromRow(row as Map<String, dynamic>, tiersByEvent));
      }

      _events = parentRows
          .map(
            (row) => _eventFromRow(
              row as Map<String, dynamic>,
              tiersByEvent,
              days: daysByParent[row['event_id'] as String] ?? const [],
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PublicEventRepositoryException('Could not load events: ${e.message}');
    }
  }

  /// Looks up a top-level event by id (not one of a multi-day event's
  /// individual days — those are reached through [EventSummary.days]).
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

  /// Turns a stored `event_banners` path into a directly-loadable public
  /// URL (the bucket is public, but Storage uploads only record the path).
  /// Returns null when no banner has been uploaded.
  String? _bannerUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from('event_banners').getPublicUrl(path);
  }

  EventSummary _eventFromRow(
    Map<String, dynamic> row,
    Map<String, List<TicketTier>> tiersByEvent, {
    List<EventSummary> days = const [],
  }) {
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
      bannerUrl: _bannerUrl(row['banner_image_url'] as String?),
      days: days,
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
