import 'package:supabase_flutter/supabase_flutter.dart';

/// What [AdminEventService.unpublishEvent] reports back.
class UnpublishResult {
  const UnpublishResult({required this.ticketsRefunded, required this.amountRefunded});
  final int ticketsRefunded;
  final double amountRefunded;
}

/// Thrown when loading or changing events as an admin fails.
class AdminEventServiceException implements Exception {
  final String message;
  const AdminEventServiceException(this.message);
}

/// One ticket tier of an event, as the admin sees it.
class AdminTierSummary {
  const AdminTierSummary({
    required this.label,
    required this.price,
    required this.total,
    required this.remaining,
  });

  /// Tier name. For a multi-day run this is prefixed with the day, e.g.
  /// "Day 2 \u2022 VIP", since each day has its own tiers and stock.
  final String label;
  final double price;
  final int total;
  final int remaining;

  int get sold => total - remaining;
  double get revenue => price * sold;
}

/// One top-level event (a single-day event, or a whole multi-day run) with
/// its organizer and sales, for the admin Events & Tickets screen.
class AdminEventSummary {
  const AdminEventSummary({
    required this.id,
    required this.title,
    required this.venue,
    required this.status,
    required this.isMultiDay,
    required this.startDate,
    required this.organizerName,
    required this.tiers,
    this.endDate,
    this.documentPaths = const [],
    this.unpublishedAt,
    this.unpublishReason,
    this.complianceDeadline,
  });

  final String id;
  final String title;
  final String venue;

  /// Raw `events.status`: draft | published | canceled | completed.
  final String status;
  final bool isMultiDay;
  final DateTime startDate;
  final DateTime? endDate;
  final String organizerName;
  final List<AdminTierSummary> tiers;

  /// Paths in the private `event_documents` bucket (supporting documents the
  /// organizer uploaded, e.g. venue contract or LGU permit).
  final List<String> documentPaths;

  /// Set when an admin unpublished the event (status goes back to 'draft').
  final DateTime? unpublishedAt;
  final String? unpublishReason;
  final DateTime? complianceDeadline;

  /// Hidden by an admin and waiting for the organizer to comply.
  bool get isUnpublished => status == 'draft' && unpublishedAt != null;

  String? get complianceLabel {
    final deadline = complianceDeadline;
    if (!isUnpublished || deadline == null) return null;
    return 'Documents due ${_fmt(deadline)}';
  }

  int get ticketsSold => tiers.fold(0, (sum, t) => sum + t.sold);
  int get ticketsTotal => tiers.fold(0, (sum, t) => sum + t.total);
  double get grossRevenue => tiers.fold(0.0, (sum, t) => sum + t.revenue);
  String get soldLabel => '$ticketsSold / $ticketsTotal';

  String get statusLabel => switch (status) {
    'draft' => isUnpublished ? 'Unpublished' : 'Draft',
    'published' => 'Published',
    'canceled' => 'Cancelled',
    'completed' => 'Completed',
    _ => status,
  };

  /// Only events that are still on or about to be on can be canceled.
  bool get canCancel => status == 'published' || status == 'draft';

  /// Unpublishing hides the event (nothing is deleted) and refunds holders.
  bool get canUnpublish => status == 'published';

  /// Admin can put an unpublished event back on sale once it complies.
  bool get canRepublish => isUnpublished;

  String get dateLabel {
    final end = endDate;
    if (!isMultiDay || end == null) return _fmt(startDate);
    return '${_fmt(startDate)} \u2013 ${_fmt(end)}';
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Admin view of every organizer's events, backed by `public.events` /
/// `public.ticket_tiers` / `public.users`. Admins can read and update all
/// events through RLS (`events_update_own_or_admin` in supabase/policies.sql).
///
/// Canceling an event here fires the same database trigger as the
/// organizer's own Cancel Event button
/// (`create_refunds_on_event_cancel`, supabase/refund_functions.sql), so a
/// pending refund is created per purchase, tickets and resale listings are
/// canceled, and each buyer is notified.
class AdminEventService {
  AdminEventService._();
  static final AdminEventService instance = AdminEventService._();

  /// Every top-level event, newest first. A multi-day run appears once, with
  /// the tiers of its generated day-events (the run's own copy of the tiers
  /// is never sold from, so counting it would double the totals).
  Future<List<AdminEventSummary>> fetchEvents() async {
    try {
      // Cancel unpublished events whose compliance deadline has passed.
      try {
        await Supabase.instance.client.rpc('cancel_lapsed_unpublished_events');
      } catch (_) {}

      final rows = await Supabase.instance.client
          .from('events')
          .select('''
            event_id, parent_event_id, day_number, event_type, title, venue,
            status, event_start_date, event_end_date, created_at,
            supporting_document_urls, unpublished_at, unpublish_reason,
            compliance_deadline,
            users(full_name, organization_name),
            ticket_tiers(tier_name, base_price, total_quantity, remaining_quantity)
          ''')
          .order('created_at', ascending: false) as List;

      final parents = <Map<String, dynamic>>[];
      final childrenByParent = <String, List<Map<String, dynamic>>>{};
      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final parentId = row['parent_event_id'] as String?;
        if (parentId == null) {
          parents.add(row);
        } else {
          childrenByParent.putIfAbsent(parentId, () => []).add(row);
        }
      }

      return [
        for (final parent in parents)
          _build(parent, childrenByParent[parent['event_id'] as String] ?? const []),
      ];
    } on PostgrestException catch (e) {
      throw AdminEventServiceException('Could not load events: ${e.message}');
    }
  }

  AdminEventSummary _build(
    Map<String, dynamic> parent,
    List<Map<String, dynamic>> children,
  ) {
    final isMulti = parent['event_type'] == 'multi_day';
    final tiers = <AdminTierSummary>[];

    if (isMulti && children.isNotEmpty) {
      final days = [...children]
        ..sort(
          (a, b) => ((a['day_number'] as int?) ?? 0).compareTo(
            (b['day_number'] as int?) ?? 0,
          ),
        );
      for (final day in days) {
        final dayNo = day['day_number'];
        tiers.addAll(_tiersOf(day, prefix: 'Day $dayNo \u2022 '));
      }
    } else {
      tiers.addAll(_tiersOf(parent));
    }

    final organizer = parent['users'] as Map<String, dynamic>?;
    final org = (organizer?['organization_name'] as String?)?.trim() ?? '';
    final name = (organizer?['full_name'] as String?)?.trim() ?? '';
    final endRaw = parent['event_end_date'] as String?;

    return AdminEventSummary(
      id: parent['event_id'] as String,
      title: parent['title'] as String,
      venue: parent['venue'] as String,
      status: parent['status'] as String,
      isMultiDay: isMulti,
      startDate: DateTime.parse(parent['event_start_date'] as String),
      endDate: endRaw == null ? null : DateTime.parse(endRaw),
      organizerName: org.isNotEmpty ? org : (name.isNotEmpty ? name : 'Unknown organizer'),
      tiers: tiers,
      documentPaths: (parent['supporting_document_urls'] as List?)?.cast<String>() ?? const [],
      unpublishedAt: _parseTs(parent['unpublished_at']),
      unpublishReason: parent['unpublish_reason'] as String?,
      complianceDeadline: _parseTs(parent['compliance_deadline']),
    );
  }

  DateTime? _parseTs(dynamic raw) =>
      raw == null ? null : DateTime.parse(raw as String).toLocal();

  List<AdminTierSummary> _tiersOf(Map<String, dynamic> event, {String prefix = ''}) {
    final raw = (event['ticket_tiers'] as List?) ?? const [];
    return [
      for (final t in raw)
        AdminTierSummary(
          label: '$prefix${(t as Map<String, dynamic>)['tier_name']}',
          price: (t['base_price'] as num).toDouble(),
          total: (t['total_quantity'] as num).toInt(),
          remaining: (t['remaining_quantity'] as num).toInt(),
        ),
    ];
  }

  /// Cancels the event (and, for a multi-day run, its day-events). Refunds
  /// and notifications are created by the database trigger.
  Future<void> cancelEvent(String eventId) => _setStatus(eventId, 'canceled');

  /// Hides the event from event goers (nothing is deleted), refunds every
  /// current ticket holder like a cancellation, and gives the organizer
  /// [deadlineDays] to submit proper documents. See
  /// supabase/admin_unpublish.sql.
  Future<UnpublishResult> unpublishEvent(
    String eventId, {
    required String reason,
    required int deadlineDays,
  }) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_unpublish_event',
        params: {
          'p_event_id': eventId,
          'p_reason': reason,
          'p_deadline_days': deadlineDays,
        },
      ) as List;
      final row = rows.isEmpty ? const <String, dynamic>{} : rows.first as Map;
      return UnpublishResult(
        ticketsRefunded: (row['tickets_refunded'] as num?)?.toInt() ?? 0,
        amountRefunded: (row['amount_refunded'] as num?)?.toDouble() ?? 0,
      );
    } on PostgrestException catch (e) {
      throw AdminEventServiceException(e.message);
    }
  }

  /// Puts an unpublished event back on sale after the organizer complied.
  Future<void> republishEvent(String eventId) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_republish_event',
        params: {'p_event_id': eventId},
      );
    } on PostgrestException catch (e) {
      throw AdminEventServiceException(e.message);
    }
  }

  Future<void> _setStatus(String eventId, String status) async {
    try {
      final updated = await Supabase.instance.client
          .from('events')
          .update({'status': status})
          .eq('event_id', eventId)
          .select('event_id') as List;
      // RLS silently matches zero rows when the caller isn't allowed to
      // update, so an empty result means nothing changed.
      if (updated.isEmpty) {
        throw const AdminEventServiceException(
          'Could not update this event. It may no longer exist, or this account is not an admin.',
        );
      }
      await Supabase.instance.client
          .from('events')
          .update({'status': status})
          .eq('parent_event_id', eventId);
    } on PostgrestException catch (e) {
      throw AdminEventServiceException('Could not update the event: ${e.message}');
    }
  }
}
