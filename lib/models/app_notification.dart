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
