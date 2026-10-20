import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_repository.dart';

/// Phone notifications powered by Supabase alone (no Firebase / FCM).
///
/// The server writes a `public.notifications` row with channel `push` for
/// events that should alert the user, such as an approved registration (see
/// `notify_user` in supabase/notification_functions.sql). While the user is
/// signed in this service:
///  1. subscribes to new notification rows for that user over Supabase
///     Realtime and shows a system notification for each `push` row, and
///  2. on start, shows any `push` rows it missed while the app was closed.
/// A row is marked read once it has been shown, so it never alerts twice.
/// (The matching `in_app` row still sits in the bell/feed as usual.)
///
/// Limit: delivery needs the app process to be running, in the foreground or
/// recently backgrounded. If the app is fully closed, the alert appears the
/// next time it opens. Waking a closed app is what FCM / APNs exist for.
///
/// Everything is best-effort and never throws to the caller. Mobile only; on
/// web this does nothing.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _pluginReady = false;
  RealtimeChannel? _channel;
  String? _userId;
  final Set<String> _shown = {};

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Call after a successful login or session restore. Starts listening for
  /// the signed-in user's push notifications. Safe to call repeatedly.
  Future<void> registerForCurrentUser() async {
    if (!_supported) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      if (_userId == userId && _channel != null) return; // already listening
      await unregister();

      await _initPlugin();
      _userId = userId;

      _channel = Supabase.instance.client
          .channel('push-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => _handle(payload.newRecord),
          )
          .subscribe();

      await _deliverMissed(userId);
    } catch (e) {
      debugPrint('Push notifications skipped: $e');
    }
  }

  /// Call on log out: stops listening so the next account on this phone does
  /// not see the previous account's alerts.
  Future<void> unregister() async {
    final channel = _channel;
    _channel = null;
    _userId = null;
    _shown.clear();
    if (channel == null) return;
    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (e) {
      debugPrint('Push unsubscribe skipped: $e');
    }
  }

  Future<void> _initPlugin() async {
    if (_pluginReady) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ and iOS ask the user for permission; older Android allows
    // notifications by default.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _pluginReady = true;
  }

  /// Shows push rows created while the app wasn't listening (closed, or the
  /// user wasn't signed in yet when an admin approved them).
  Future<void> _deliverMissed(String userId) async {
    final rows =
        await Supabase.instance.client
                .from('notifications')
                .select()
                .eq('user_id', userId)
                .eq('channel', 'push')
                .eq('is_read', false)
                .order('sent_at', ascending: true)
                .limit(20)
            as List;
    for (final row in rows) {
      await _handle(Map<String, dynamic>.from(row as Map));
    }
  }

  Future<void> _handle(Map<String, dynamic> row) async {
    if (row['channel'] != 'push') return;
    final id = row['notification_id'] as String?;
    if (id == null || !_shown.add(id)) return; // already shown

    try {
      await _plugin.show(
        id.hashCode & 0x7fffffff,
        row['title'] as String?,
        row['message'] as String?,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fairtix_alerts',
            'FairTix alerts',
            channelDescription: 'Account approvals and other important updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      // Mark the push row read so it is never shown again, then refresh the
      // bell (the in-app copy of the same notification).
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', id);
      unawaited(NotificationRepository.instance.refresh());
    } catch (e) {
      _shown.remove(id);
      debugPrint('Could not show notification: $e');
    }
  }
}
