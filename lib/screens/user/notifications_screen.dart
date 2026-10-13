import 'package:flutter/material.dart';

import '../../data/sample_notifications.dart';
import '../../data/sample_tickets.dart';
import '../../models/app_notification.dart';
import '../../models/ticket.dart';
import '../../services/notification_repository.dart';
import '../../theme/app_theme.dart';
import 'ticket_sold_screen.dart';

/// In-app notification feed, shared by event goers, organizers and admins.
///
/// Shows the signed-in user's notifications from `public.notifications`
/// (see supabase/notification_functions.sql) — purchase, resale listing and
/// sale, cancellation, refund, account review, etc. Tapping a notification
/// marks it as read and the change is saved to the database, so it stays
/// read after a restart. Pull down to refresh.
///
/// The local demo "ticket sold" entries created by the resale flow
/// ([sampleNotifications]) are still listed first and keep their original
/// behavior (tap opens the Ticket Sold confirmation) until resale itself
/// is backed by Supabase.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _remote = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final list = await NotificationRepository.instance.fetch();
      if (!mounted) return;
      setState(() {
        _remote = list;
        _errorMessage = null;
      });
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasUnread => _remote.any((n) => !n.isRead) || sampleNotifications.any((n) => !n.isRead);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllRead() async {
    final previous = _remote;
    setState(() {
      _remote = [for (final n in _remote) n.copyWith(isRead: true)];
      for (var i = 0; i < sampleNotifications.length; i++) {
        sampleNotifications[i] = sampleNotifications[i].copyWith(isRead: true);
      }
    });
    try {
      await NotificationRepository.instance.markAllRead();
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _remote = previous);
      _showMessage(e.message);
    }
  }

  Future<void> _handleRemoteTap(AppNotification notification) async {
    if (notification.isRead) return;
    final index = _remote.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;
    setState(() => _remote[index] = notification.copyWith(isRead: true));
    try {
      await NotificationRepository.instance.markRead(notification.id);
    } on NotificationRepositoryException catch (e) {
      if (!mounted) return;
      // Couldn't save it — put the unread dot back so the screen doesn't
      // claim something that isn't true.
      setState(() => _remote[index] = notification);
      _showMessage(e.message);
    }
  }

  void _handleLocalTap(AppNotification notification) {
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
    // wallet (ownership has transferred to the buyer). The one-ticket-per-
    // account purchase limit is enforced server-side, so nothing else to
    // record locally.
    sampleMyTickets.removeWhere((t) => t.id == ticket!.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketSoldScreen(
          ticket: ticket!,
          // TODO(backend): resolve the real buyer from the resale
          // TRANSACTIONS record's buyer_id once the resale backend is
          // wired up. TicketSoldScreen doesn't currently display this
          // name (it just shows a "Confirmed" badge), so this is a safe
          // non-identifying placeholder in the meantime.
          buyerName: 'A verified buyer',
          salePrice: ticket.resalePrice ?? ticket.tier.price,
        ),
      ),
    );
  }

  void _handleTap(AppNotification notification) {
    if (notification.isRemote) {
      _handleRemoteTap(notification);
    } else {
      _handleLocalTap(notification);
    }
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.accentPurple.withValues(alpha: 0.35)),
              const SizedBox(height: 14),
              const Text('No notifications yet', style: AppTextStyles.sectionHeading),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = [...sampleNotifications, ..._remote];
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
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentPurple))
            : (_errorMessage != null && notifications.isEmpty)
                ? _errorState()
                : notifications.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
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
        AppNotificationType.resale => Icons.sell_rounded,
        AppNotificationType.ticket => Icons.confirmation_number_rounded,
        AppNotificationType.system => Icons.verified_user_rounded,
        AppNotificationType.promo => Icons.local_offer_rounded,
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.textDark,
                          ),
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
