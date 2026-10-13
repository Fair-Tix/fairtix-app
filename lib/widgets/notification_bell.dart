import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/user/notifications_screen.dart';
import '../services/notification_repository.dart';

/// Bell icon with an unread dot. Tapping it opens the notification feed.
///
/// Used in the organizer and admin top bars (the event goer dashboard has
/// its own styled bell). Checks for new notifications when it appears and
/// every 30 seconds after, and again when the feed is closed.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.color = const Color(0xFF6B7280),
    this.size = 22,
    this.badgeBorderColor = Colors.white,
  });

  final Color color;
  final double size;

  /// Ring around the unread dot — set to the bar's background color.
  final Color badgeBorderColor;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    NotificationRepository.instance.refreshUnreadCount();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => NotificationRepository.instance.refreshUnreadCount(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await NotificationRepository.instance.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationRepository.instance.unreadCount,
      builder: (context, count, _) {
        return InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, size: widget.size, color: widget.color),
                if (count > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.badgeBorderColor, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
