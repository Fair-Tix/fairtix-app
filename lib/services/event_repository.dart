import 'dart:typed_data';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organizer_event.dart';

/// Thrown when an event-related Supabase read/write fails.
class EventRepositoryException implements Exception {
  final String message;
  const EventRepositoryException(this.message);
}

/// What [EventRepository.cancelEvent] reports back.
class CancelResult {
  final int ticketsRefunded;
  final double amountRefunded;
  const CancelResult({
    required this.ticketsRefunded,
    required this.amountRefunded,
  });
}

/// The signed-in organizer's events, backed by `public.events` /
/// `public.ticket_tiers` (see supabase/schema.sql).
///
/// Screens call the async [refresh] once (e.g. in `initState`) to pull the
/// latest rows from Supabase into a local cache, then read the synchronous
/// [events] / [getById] getters exactly as before — this keeps
/// My Events / the Dashboard / Edit Event free of further changes.
///
/// Event creation, edits and cancellations use the SECURITY DEFINER RPCs in
/// supabase/organizer_event_functions.sql. Deletes use the table's row
/// policies. Every successful write refreshes the local cache before returning.
class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  List<OrganizerEvent> _events = [];

  /// Read-only snapshot of the organizer's events. Top-level only — a
  /// multi-day run's generated per-day child rows are rolled up under
  /// their parent (see [OrganizerEvent.span]), so this always shows one
  /// line per event series.
  List<OrganizerEvent> get events => List.unmodifiable(_events);

  int get totalTicketsSold => _events.fold(0, (sum, e) => sum + e.ticketsSold);

  double get totalGrossRevenue =>
      _events.fold(0.0, (sum, e) => sum + e.grossRevenue);

  /// Turns a stored `event_banners` path (what [OrganizerEvent.bannerUrl]
  /// holds) into a directly-loadable public URL, since the bucket is
  /// public but Storage upload calls only return the path, not the URL.
  /// Returns null if [path] is null (no banner uploaded yet).
  String? publicBannerUrl(String? path) {
    if (path == null) return null;
    return Supabase.instance.client.storage
        .from('event_banners')
        .getPublicUrl(path);
  }

  OrganizerEvent? getById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// Fetches the signed-in organizer's own top-level events (parent_event_id
  /// is null — i.e. single-day events and multi-day parents, never the
  /// generated day-children) plus each one's ticket tiers, and replaces the
  /// local cache.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _events = [];
      return;
    }
    try {
      final eventRows =
          await Supabase.instance.client
                  .from('events')
                  .select()
                  .eq('organizer_id', userId)
                  .isFilter('parent_event_id', null)
                  .order('created_at', ascending: false)
              as List;

      final eventIds = eventRows
          .map((row) => row['event_id'] as String)
          .toList();

      // Per-day child rows of multi-day parents. Purchases happen against a
      // day's own tiers (see create_event_with_days), so a parent's sold /
      // remaining / revenue figures are rolled up from its days.
      final childRows = eventIds.isEmpty
          ? <dynamic>[]
          : await Supabase.instance.client
                    .from('events')
                    .select('event_id, parent_event_id, day_number, status')
                    .inFilter('parent_event_id', eventIds)
                as List;
      final childIdsByParent = <String, List<String>>{};
      for (final row in childRows) {
        // Canceled days no longer count toward live inventory.
        if (row['status'] == 'canceled') continue;
        childIdsByParent
            .putIfAbsent(row['parent_event_id'] as String, () => [])
            .add(row['event_id'] as String);
      }

      final allIds = [
        ...eventIds,
        for (final ids in childIdsByParent.values) ...ids,
      ];

      final tiersByEvent = <String, List<TicketTier>>{};
      if (allIds.isNotEmpty) {
        final tierRows =
            await Supabase.instance.client
                    .from('ticket_tiers')
                    .select()
                    .inFilter('event_id', allIds)
                as List;
        for (final row in tierRows) {
          final eventId = row['event_id'] as String;
          tiersByEvent
              .putIfAbsent(eventId, () => [])
              .add(_tierFromRow(row as Map<String, dynamic>));
        }
      }

      // Roll each multi-day parent's tiers up from its live days.
      for (final entry in childIdsByParent.entries) {
        final merged = <String, TicketTier>{};
        for (final childId in entry.value) {
          for (final tier in tiersByEvent[childId] ?? const <TicketTier>[]) {
            final existing = merged[tier.name];
            merged[tier.name] = existing == null
                ? tier
                : TicketTier(
                    name: tier.name,
                    price: tier.price,
                    quantity: existing.quantity + tier.quantity,
                    sold: existing.sold + tier.sold,
                  );
          }
        }
        if (merged.isNotEmpty) {
          tiersByEvent[entry.key] = merged.values.toList();
        }
      }

      _events = eventRows.map((row) {
        final event = _eventFromRow(row as Map<String, dynamic>, tiersByEvent);
        return event.isMultiDay
            ? event.copyWith(dayCount: childIdsByParent[event.id]?.length ?? 0)
            : event;
      }).toList();
    } on PostgrestException catch (e) {
      throw EventRepositoryException(
        'Could not load your events: ${e.message}',
      );
    }
  }

  /// Creates a new event for the signed-in organizer.
  ///
  /// Single-day: inserts one `events` row.
  ///
  /// Multi-day: inserts a parent `events` row spanning [startDate]–[endDate],
  /// then generates one child `events` row per calendar day in that range,
  /// each linked back via `parent_event_id` and numbered via `day_number`
  /// (the "Multi-Day Sub-Event Generation" step from
  /// docs/FairTix-Backend-Roadmap.md, Phase 2). Every day — parent included,
  /// so buyers browsing the parent's own tiers still see something — gets
  /// its own copy of [tiers], since `ticket_tiers` (and its
  /// sold/remaining inventory) is scoped to a single `event_id` in the
  /// schema; there's no shared-inventory concept across the days of one run.
  ///
  /// Refreshes the local cache before returning, so the newly created event
  /// is immediately visible via [events] / [getById].
  Future<OrganizerEvent> createEvent({
    required String name,
    required String venue,
    required DateTime startDate,
    DateTime? endDate,
    EventSpan span = EventSpan.singleDay,
    String description = '',
    EventStatus status = EventStatus.published,
    List<TicketTier> tiers = const [],
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const EventRepositoryException(
        'You need to be signed in to create an event.',
      );
    }
    if (span == EventSpan.multiDay &&
        (endDate == null || !endDate.isAfter(startDate))) {
      throw const EventRepositoryException(
        'Multi-day events need an end date after the start date.',
      );
    }

    try {
      final eventId = await Supabase.instance.client.rpc(
        'create_event_with_days',
        params: {
          'p_title': name,
          'p_venue': venue,
          'p_description': description,
          'p_event_type': span == EventSpan.multiDay
              ? 'multi_day'
              : 'single_day',
          'p_start_date': _isoDate(startDate),
          'p_end_date': span == EventSpan.multiDay ? _isoDate(endDate!) : null,
          'p_status': _statusToRow(status),
          'p_tiers': [
            for (final t in tiers)
              {'name': t.name, 'price': t.price, 'quantity': t.quantity},
          ],
        },
      ) as String;
      await refresh();
      final created = getById(eventId);
      if (created == null) {
        throw const EventRepositoryException(
          'Your event was created but could not be reloaded. Pull to refresh.',
        );
      }
      return created;
    } on PostgrestException catch (e) {
      throw EventRepositoryException(e.message);
    }
  }

  /// The per-day child rows of a multi-day [parentId] (day 1..N), each with
  /// its own tiers — used by the cancel screen to offer "cancel a single
  /// day".
  Future<List<OrganizerEvent>> fetchDays(String parentId) async {
    try {
      final rows =
          await Supabase.instance.client
                  .from('events')
                  .select()
                  .eq('parent_event_id', parentId)
                  .order('day_number', ascending: true)
              as List;
      final ids = rows.map((r) => r['event_id'] as String).toList();
      final tiersByEvent = <String, List<TicketTier>>{};
      if (ids.isNotEmpty) {
        final tierRows =
            await Supabase.instance.client
                    .from('ticket_tiers')
                    .select()
                    .inFilter('event_id', ids)
                as List;
        for (final row in tierRows) {
          tiersByEvent
              .putIfAbsent(row['event_id'] as String, () => [])
              .add(_tierFromRow(row as Map<String, dynamic>));
        }
      }
      return rows
          .map((r) => _eventFromRow(r as Map<String, dynamic>, tiersByEvent))
          .toList();
    } on PostgrestException catch (e) {
      throw EventRepositoryException(
        'Could not load the event days: ${e.message}',
      );
    }
  }

  /// Uploads [bytes] as the banner image for [eventId] (the event returned
  /// by [createEvent] — an event row, and so a folder the
  /// `event_banners_insert_owning_organizer_or_admin` policy will allow,
  /// must already exist before this can succeed) to the public
  /// `event_banners` bucket, records the path on
  /// `public.events.banner_image_url`, and — if [eventId] is a multi-day
  /// parent — copies the same banner onto every generated day-child so
  /// each day's page shows it too. Refreshes the local cache before
  /// returning.
  Future<String> uploadEventBanner({
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.replaceFirst('.', '').toLowerCase();
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path =
        '$eventId/banner_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final contentType = 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}';

    try {
      await Supabase.instance.client.storage
          .from('event_banners')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      await Supabase.instance.client
          .from('events')
          .update({'banner_image_url': path})
          .eq('event_id', eventId);

      // Multi-day parent: propagate the same banner to every generated
      // day-child (a no-op update if there are none, e.g. single-day).
      await Supabase.instance.client
          .from('events')
          .update({'banner_image_url': path})
          .eq('parent_event_id', eventId);
    } on StorageException catch (e) {
      throw EventRepositoryException(
        'Could not upload the banner: ${e.message}',
      );
    } on PostgrestException catch (e) {
      throw EventRepositoryException('Could not save the banner: ${e.message}');
    }

    await refresh();
    return path;
  }

  /// Uploads [bytes] as a supporting document (venue contract, LGU permit,
  /// etc.) for [eventId] to the private `event_documents` bucket, and
  /// appends the resulting path to
  /// `public.events.supporting_document_urls`. Like [uploadEventBanner],
  /// [eventId] must already exist. Call once per document; if [eventId] is
  /// a multi-day parent, the same growing list is copied onto every
  /// generated day-child after each call. Refreshes the local cache before
  /// returning.
  Future<String> uploadEventDocument({
    required String eventId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = '$eventId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      await Supabase.instance.client.storage
          .from('event_documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final current = await Supabase.instance.client
          .from('events')
          .select('supporting_document_urls')
          .eq('event_id', eventId)
          .single();
      final updatedUrls = [
        ...((current['supporting_document_urls'] as List?)?.cast<String>() ??
            const []),
        path,
      ];

      await Supabase.instance.client
          .from('events')
          .update({'supporting_document_urls': updatedUrls})
          .eq('event_id', eventId);

      await Supabase.instance.client
          .from('events')
          .update({'supporting_document_urls': updatedUrls})
          .eq('parent_event_id', eventId);
    } on StorageException catch (e) {
      throw EventRepositoryException(
        'Could not upload the document: ${e.message}',
      );
    } on PostgrestException catch (e) {
      throw EventRepositoryException(
        'Could not save the document: ${e.message}',
      );
    }

    await refresh();
    return path;
  }

  // ── Persisted mutations (RPCs in organizer_event_functions.sql) ──────

  /// Saves edits to [updated] (name, venue, description, tiers and, when
  /// [publish] is true, publishes a draft). Sold counts are preserved
  /// server-side. Refreshes the cache before returning.
  Future<void> updateEvent(
    OrganizerEvent updated, {
    bool publish = false,
  }) async {
    try {
      await Supabase.instance.client.rpc(
        'update_event_details',
        params: {
          'p_event_id': updated.id,
          'p_title': updated.name,
          'p_venue': updated.venue,
          'p_description': updated.description,
          'p_tiers': [
            for (final t in updated.tiers)
              {'name': t.name, 'price': t.price, 'quantity': t.quantity},
          ],
          'p_status': publish ? 'published' : null,
        },
      );
    } on PostgrestException catch (e) {
      throw EventRepositoryException(e.message);
    }
    await refresh();
  }

  /// Cancels [id]. Pass a multi-day parent's id to cancel the whole run, or
  /// one day's id (see [fetchDays]) to cancel just that day. The server marks
  /// the event(s) canceled, invalidates tickets, refunds current holders and
  /// notifies them, all in one transaction.
  Future<CancelResult> cancelEvent(String id, {String? reason}) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'cancel_event',
        params: {'p_event_id': id, 'p_reason': reason},
      ) as List;
      final row = rows.isEmpty ? const <String, dynamic>{} : rows.first as Map;
      await refresh();
      return CancelResult(
        ticketsRefunded: (row['tickets_refunded'] as num?)?.toInt() ?? 0,
        amountRefunded: (row['amount_refunded'] as num?)?.toDouble() ?? 0,
      );
    } on PostgrestException catch (e) {
      throw EventRepositoryException(e.message);
    }
  }

  /// Permanently deletes [id]. Fails (and says so) if tickets were already
  /// sold — those events must be canceled so buyers get refunded instead.
  Future<void> deleteEvent(String id) async {
    try {
      await Supabase.instance.client.from('events').delete().eq('event_id', id);
    } on PostgrestException catch (e) {
      throw EventRepositoryException(
        e.code == '23503'
            ? 'This event already has ticket sales. Cancel it instead so buyers are refunded.'
            : 'Could not delete the event: ${e.message}',
      );
    }
    await refresh();
  }

  /// Calls [onChange] whenever a ticket tier's inventory changes (i.e. after
  /// each purchase / refund), so the sales screen can update live. Returns a
  /// callback that stops listening. Requires `ticket_tiers` to be in the
  /// `supabase_realtime` publication (see organizer_event_functions.sql).
  VoidCallback listenForSales(VoidCallback onChange) {
    final channel = Supabase.instance.client
        .channel('organizer-sales-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ticket_tiers',
          callback: (_) => onChange(),
        )
        .subscribe();
    return () {
      Supabase.instance.client.removeChannel(channel);
    };
  }

  // ── Row <-> model mapping ───────────────────────────────────────────────

  TicketTier _tierFromRow(Map<String, dynamic> row) {
    final totalQuantity = row['total_quantity'] as int;
    final remainingQuantity = row['remaining_quantity'] as int;
    return TicketTier(
      name: row['tier_name'] as String,
      price: (row['base_price'] as num).toDouble(),
      quantity: totalQuantity,
      sold: totalQuantity - remainingQuantity,
    );
  }

  OrganizerEvent _eventFromRow(
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
    return OrganizerEvent(
      id: eventId,
      name: row['title'] as String,
      date: dateLabel,
      venue: row['venue'] as String,
      description: (row['description'] as String?) ?? '',
      status: _statusFromRow(row['status'] as String),
      tiers: tiersByEvent[eventId] ?? const [],
      span: isMulti ? EventSpan.multiDay : EventSpan.singleDay,
      parentEventId: row['parent_event_id'] as String?,
      dayNumber: row['day_number'] as int?,
      bannerUrl: row['banner_image_url'] as String?,
      supportingDocumentUrls:
          (row['supporting_document_urls'] as List?)?.cast<String>() ??
          const [],
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

  String _statusToRow(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'draft';
      case EventStatus.published:
        return 'published';
      case EventStatus.cancelled:
        return 'canceled';
      case EventStatus.completed:
        return 'completed';
    }
  }

  EventStatus _statusFromRow(String status) {
    switch (status) {
      case 'draft':
        return EventStatus.draft;
      case 'canceled':
        return EventStatus.cancelled;
      case 'completed':
        return EventStatus.completed;
      default:
        return EventStatus.published;
    }
  }
}
