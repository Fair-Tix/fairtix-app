/// Placeholder in-app notification model for UI scaffolding.
/// TODO: replace with real push/in-app notifications delivered via FCM
/// once the backend is wired up (e.g. triggered by a Cloud Function when
/// a RESALE_LISTINGS record's status flips to sold).
enum AppNotificationType { ticketSold, general }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.type = AppNotificationType.general,
    this.isRead = false,
    this.relatedTicketId,
  });

  final String id;
  final String title;
  final String message;
  final String timeLabel;
  final AppNotificationType type;
  final bool isRead;

  /// For [AppNotificationType.ticketSold] notifications, the id of the
  /// ticket in `sampleMyTickets` this notification relates to.
  final String? relatedTicketId;

  /// Builds a notification from a `public.notifications` row (see
  /// supabase/schema.sql, Table 15). Ticket-sold notifications need a
  /// `relatedTicketId`, which the table has no column for yet, so every
  /// DB-backed notification is [AppNotificationType.general] for now.
  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final sentAt = DateTime.tryParse(row['sent_at'] as String? ?? '')?.toLocal();
    return AppNotification(
      id: row['notification_id'] as String,
      title: row['title'] as String? ?? '',
      message: row['message'] as String? ?? '',
      timeLabel: sentAt == null ? '' : _relativeTime(sentAt),
      isRead: row['is_read'] as bool? ?? false,
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      timeLabel: timeLabel,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedTicketId: relatedTicketId,
    );
  }
}
