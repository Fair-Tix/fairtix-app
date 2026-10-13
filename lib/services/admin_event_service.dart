import 'package:supabase_flutter/supabase_flutter.dart';

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

  int get ticketsSold => tiers.fold(0, (sum, t) => sum + t.sold);
  int get ticketsTotal => tiers.fold(0, (sum, t) => sum + t.total);
  double get grossRevenue => tiers.fold(0.0, (sum, t) => sum + t.revenue);
  String get soldLabel => '$ticketsSold / $ticketsTotal';

  String get statusLabel => switch (status) {
    'draft' => 'Draft',
    'published' => 'Published',
    'canceled' => 'Cancelled',
    'completed' => 'Completed',
    _ => status,
  };

  /// Only events that are still on or about to be on can be canceled.
  bool get canCancel => status == 'published' || status == 'draft';

  /// Unpublishing stops new sales without canceling or refunding anything.
  bool get canUnpublish => status == 'published';

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
      final rows = await Supabase.instance.client
          .from('events')
          .select('''
            event_id, parent_event_id, day_number, event_type, title, venue,
            status, event_start_date, event_end_date, created_at,
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
    );
  }

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

  /// Takes the event off sale (back to draft) without canceling it.
  Future<void> unpublishEvent(String eventId) => _setStatus(eventId, 'draft');

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
