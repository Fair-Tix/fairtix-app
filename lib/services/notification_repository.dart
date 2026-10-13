import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// Thrown when loading or updating notifications fails.
class NotificationRepositoryException implements Exception {
  final String message;
  const NotificationRepositoryException(this.message);

  @override
  String toString() => message;
}

/// The signed-in user's in-app notifications, backed by
/// `public.notifications` (rows with channel `in_app`; the matching
/// `email` rows are for the email Edge Function and never shown here).
///
/// Works for every role — event goer, organizer and admin — because
/// notifications are addressed to a user id, not a role.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  /// Number of unread in-app notifications, for the bell badge. Updated by
  /// [fetch], [refreshUnreadCount], [markRead] and [markAllRead].
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  /// Latest in-app notifications, newest first.
  ///
  /// The user id filter is explicit on purpose: admins are allowed (by
  /// RLS) to read every row in the table, and must still only see their
  /// own notifications here.
  Future<List<AppNotification>> fetch({int limit = 100}) async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final rows =
          await Supabase.instance.client
                  .from('notifications')
                  .select()
                  .eq('user_id', userId)
                  .eq('channel', 'in_app')
                  .order('sent_at', ascending: false)
                  .limit(limit)
              as List;
      final list = rows.map((r) => AppNotification.fromRow(r as Map<String, dynamic>)).toList();
      unreadCount.value = list.where((n) => !n.isRead).length;
      return list;
    } on PostgrestException catch (e) {
      throw NotificationRepositoryException('Could not load notifications: ${e.message}');
    } catch (_) {
      throw const NotificationRepositoryException('Could not load notifications. Check your connection and try again.');
    }
  }

  /// Refreshes just the unread count (cheap; used by the bell icon).
  /// Failures are swallowed — a stale badge is better than an error popup.
  Future<void> refreshUnreadCount() async {
    final userId = _userId;
    if (userId == null) {
      unreadCount.value = 0;
      return;
    }
    try {
      final rows =
          await Supabase.instance.client
                  .from('notifications')
                  .select('notification_id')
                  .eq('user_id', userId)
                  .eq('channel', 'in_app')
                  .eq('is_read', false)
                  .limit(100)
              as List;
      unreadCount.value = rows.length;
    } catch (_) {
      // Keep the last known count.
    }
  }

  /// Marks one notification as read and saves it.
  Future<void> markRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId)
          .eq('user_id', userId);
      if (unreadCount.value > 0) unreadCount.value = unreadCount.value - 1;
    } on PostgrestException catch (e) {
      throw NotificationRepositoryException('Could not mark as read: ${e.message}');
    } catch (_) {
      throw const NotificationRepositoryException('Could not mark as read. Check your connection and try again.');
    }
  }

  /// Marks every unread in-app notification as read and saves it.
  Future<void> markAllRead() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('channel', 'in_app')
          .eq('is_read', false);
      unreadCount.value = 0;
    } on PostgrestException catch (e) {
      throw NotificationRepositoryException('Could not mark all as read: ${e.message}');
    } catch (_) {
      throw const NotificationRepositoryException('Could not mark all as read. Check your connection and try again.');
    }
  }
}
