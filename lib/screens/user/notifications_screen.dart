import 'package:flutter/material.dart';

import '../../data/sample_notifications.dart';
import '../../data/sample_tickets.dart';
import '../../models/app_notification.dart';
import '../../models/ticket.dart';
import '../../theme/app_theme.dart';
import 'ticket_sold_screen.dart';

/// In-app notification feed. Currently the only actionable notification
/// type is [AppNotificationType.ticketSold] — tapping one opens the
/// Ticket Sold confirmation for the seller. Tapping any notification
/// marks it as read.
/// TODO: replace `sampleNotifications` with a real feed (FCM message
/// history or a NOTIFICATIONS collection) once the backend is wired up.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  void _handleTap(AppNotification notification) {
    final index = sampleNotifications.indexWhere((n) => n.id == notification.id);
    if (index != -1 && !sampleNotifications[index].isRead) {
      setState(() => sampleNotifications[index] = sampleNotifications[index].copyWith(isRead: true));
    }

    if (notification.type != AppNotificationType.ticketSold) return;
    Ticket? ticket;
    for (final t in sampleMyTickets) {
      if (t.id == notification.relatedTicketId) {
        ticket = t;
        break;
      }
    }
    if (ticket == null) return;

    // Simulate the resale completing: the ticket leaves the seller's
    // wallet (ownership has transferred to the buyer), and the event is
    // recorded as one the seller has already resold, so FairTix's
    // one-ticket-per-account purchase limit blocks them from buying
    // another ticket for the same event afterward.
    sampleMyTickets.removeWhere((t) => t.id == ticket!.id);
    soldTicketEventIds.add(ticket.event.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketSoldScreen(
          ticket: ticket!,
          buyerName: 'Justine Manalo',
          salePrice: ticket.resalePrice ?? ticket.tier.price,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = sampleNotifications;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.35)),
                  const SizedBox(height: 14),
                  const Text('No notifications yet', style: AppTextStyles.sectionHeading),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _handleTap(notification),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        AppNotificationType.ticketSold => Icons.sell_rounded,
        AppNotificationType.general => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: AppColors.accentPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(color: AppColors.accentPurple, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notification.message, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(notification.timeLabel, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
