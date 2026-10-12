import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sample_notifications.dart';
import '../models/app_notification.dart';

/// Thrown when loading or updating notifications fails.
class NotificationRepositoryException implements Exception {
  final String message;
  const NotificationRepositoryException(this.message);
}

/// Loads the signed-in user's in-app notifications from the Postgres
/// `notifications` table (supabase/schema.sql, Table 15).
///
/// Rows are cached in the existing [sampleNotifications] list so the
/// dashboard's unread dot and the notifications screen keep reading from
/// the same place — [refresh] replaces that list's contents.
///
/// Notifications are CREATED server-side (Postgres triggers / Edge
/// Functions), never by the client: `notifications_insert_admin_only` in
/// supabase/policies.sql blocks direct client inserts. Clients can only
/// read their own rows and mark them read.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      sampleNotifications.clear();
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('channel', 'in_app')
          .order('sent_at', ascending: false);
      final loaded = (rows as List)
          .map((row) => AppNotification.fromRow(row as Map<String, dynamic>))
          .toList();
      sampleNotifications
        ..clear()
        ..addAll(loaded);
    } on PostgrestException catch (e) {
      throw NotificationRepositoryException(
        'Could not load notifications: ${e.message}',
      );
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } on PostgrestException catch (e) {
      throw NotificationRepositoryException(
        'Could not mark notification as read: ${e.message}',
      );
    }
  }
}
