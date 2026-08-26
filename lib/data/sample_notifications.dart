import '../models/app_notification.dart';

/// Placeholder notification feed for UI scaffolding.
/// TODO: replace with a real query against a NOTIFICATIONS collection
/// (or FCM message history) filtered by the current user once wired up.
final List<AppNotification> sampleNotifications = [
  AppNotification(
    id: 'ntf_0001',
    title: 'Your ticket has been bought!',
    message: 'Your A1 – Love in the Philippines Tour 2026 (VIP) listing sold for \u20b15,000.00.',
    timeLabel: '2 minutes ago',
    type: AppNotificationType.ticketSold,
    relatedTicketId: 'tkt_0001',
  ),
  AppNotification(
    id: 'ntf_0002',
    title: 'Verification approved',
    message: 'Your identity has been verified. Welcome to FairTix!',
    timeLabel: 'Yesterday',
    isRead: true,
  ),
];
