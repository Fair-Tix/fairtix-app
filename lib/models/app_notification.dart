/// An in-app notification.
///
/// Two sources feed the notification screen:
///  * REMOTE — rows from `public.notifications` (channel `in_app`), written
///    by the database triggers in supabase/notification_functions.sql
///    (purchase, resale, cancellation, refund, account review, ...). Their
///    read state is saved back to the database.
///  * LOCAL — the demo "ticket sold" entries still created in-memory by the
///    resale flow (see data/sample_notifications.dart) until resale is
///    fully backed by Supabase.
///
/// [ticketSold] / [general] are the original local types; [ticket],
/// [resale], [system] and [promo] mirror the `notification_type` enum.
enum AppNotificationType { ticketSold, general, ticket, resale, system, promo }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.type = AppNotificationType.general,
    this.isRead = false,
    this.relatedTicketId,
    this.isRemote = false,
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

  /// True when this came from `public.notifications` (so reading it must
  /// be saved to the database), false for the local demo entries.
  final bool isRemote;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      timeLabel: timeLabel,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedTicketId: relatedTicketId,
      isRemote: isRemote,
    );
  }

  /// Builds a notification from a `public.notifications` row.
  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final sentAt = DateTime.tryParse((row['sent_at'] as String?) ?? '')?.toLocal();
    return AppNotification(
      id: row['notification_id'] as String,
      title: (row['title'] as String?) ?? '',
      message: (row['message'] as String?) ?? '',
      timeLabel: sentAt == null ? '' : relativeTimeLabel(sentAt),
      type: switch (row['type'] as String?) {
        'ticket' => AppNotificationType.ticket,
        'resale' => AppNotificationType.resale,
        'system' => AppNotificationType.system,
        'promo' => AppNotificationType.promo,
        _ => AppNotificationType.general,
      },
      isRead: (row['is_read'] as bool?) ?? false,
      isRemote: true,
    );
  }

  /// "Just now", "5 min ago", "3 hr ago", "2 days ago", or a date.
  static String relativeTimeLabel(DateTime sentAt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(sentAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[sentAt.month - 1]} ${sentAt.day}, ${sentAt.year}';
  }
}
