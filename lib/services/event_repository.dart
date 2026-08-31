import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/organizer_event.dart';

/// Thrown when an event-related Supabase read/write fails.
class EventRepositoryException implements Exception {
  final String message;
  const EventRepositoryException(this.message);
}

/// The signed-in organizer's events, backed by `public.events` /
/// `public.ticket_tiers` (see supabase/schema.sql).
///
/// Screens call the async [refresh] once (e.g. in `initState`) to pull the
/// latest rows from Supabase into a local cache, then read the synchronous
/// [events] / [getById] getters exactly as before — this keeps
/// My Events / the Dashboard / Edit Event free of further changes.
///
/// [createEvent] is the one write path currently wired to Supabase (see
/// organizer-create-event.dart). [updateEvent], [cancelEvent], and
/// [deleteEvent] still only mutate the local cache — persisting those is
/// still open TODO(backend) work (Phase 2 follow-up), same as before this
/// change; a [refresh] after using this class will not reflect an edit or
/// cancel made only through those three methods.
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

      final tiersByEvent = <String, List<TicketTier>>{};
      if (eventIds.isNotEmpty) {
        final tierRows =
            await Supabase.instance.client
                    .from('ticket_tiers')
                    .select()
                    .inFilter('event_id', eventIds)
                as List;
        for (final row in tierRows) {
          final eventId = row['event_id'] as String;
          tiersByEvent
              .putIfAbsent(eventId, () => [])
              .add(_tierFromRow(row as Map<String, dynamic>));
        }
      }

      _events = eventRows
          .map(
            (row) => _eventFromRow(row as Map<String, dynamic>, tiersByEvent),
          )
          .toList();
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
      if (span == EventSpan.singleDay) {
        final inserted = await Supabase.instance.client
            .from('events')
            .insert({
              'event_type': 'single_day',
              'organizer_id': userId,
              'title': name,
              'description': description.isEmpty ? null : description,
              'venue': venue,
              'status': _statusToRow(status),
              'event_start_date': _isoDate(startDate),
            })
            .select()
            .single();
        final eventId = inserted['event_id'] as String;
        await _insertTiers(eventId, tiers);
        await refresh();
        return getById(eventId) ?? _eventFromRow(inserted, {eventId: tiers});
      }

      // Multi-day parent (container) row.
      final parentInserted = await Supabase.instance.client
          .from('events')
          .insert({
            'event_type': 'multi_day',
            'organizer_id': userId,
            'title': name,
            'description': description.isEmpty ? null : description,
            'venue': venue,
            'status': _statusToRow(status),
            'event_start_date': _isoDate(startDate),
            'event_end_date': _isoDate(endDate!),
          })
          .select()
          .single();
      final parentId = parentInserted['event_id'] as String;
      await _insertTiers(parentId, tiers);

      final totalDays = endDate.difference(startDate).inDays + 1;
      for (var i = 0; i < totalDays; i++) {
        final dayDate = startDate.add(Duration(days: i));
        final dayInserted = await Supabase.instance.client
            .from('events')
            .insert({
              'event_type': 'multi_day',
              'organizer_id': userId,
              'parent_event_id': parentId,
              'day_number': i + 1,
              'title': '$name \u2014 Day ${i + 1}',
              'description': description.isEmpty ? null : description,
              'venue': venue,
              'status': _statusToRow(status),
              'event_start_date': _isoDate(dayDate),
            })
            .select()
            .single();
        await _insertTiers(dayInserted['event_id'] as String, tiers);
      }

      await refresh();
      return getById(parentId) ??
          _eventFromRow(parentInserted, {parentId: tiers});
    } on PostgrestException catch (e) {
      throw EventRepositoryException(
        'Could not create your event: ${e.message}',
      );
    }
  }

  Future<void> _insertTiers(String eventId, List<TicketTier> tiers) async {
    if (tiers.isEmpty) return;
    await Supabase.instance.client.from('ticket_tiers').insert([
      for (final tier in tiers)
        {
          'event_id': eventId,
          'tier_name': tier.name,
          'base_price': tier.price,
          'total_quantity': tier.quantity,
          'remaining_quantity': tier.quantity,
        },
    ]);
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

  // ── Local-cache-only mutations (not yet backed by Supabase) ───────────

  void updateEvent(OrganizerEvent updated) {
    final index = _events.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _events[index] = updated;
    }
  }

  void cancelEvent(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index] = _events[index].copyWith(status: EventStatus.cancelled);
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
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
