import '../models/app_notification.dart';

/// In-app notification feed for the current user.
/// TODO(backend): replace with a real query against a NOTIFICATIONS
/// collection (or FCM message history) filtered by the current user
/// once wired up.
///
/// Starts empty on every app run — no sample/dummy notifications are
/// seeded here. Screens that read this already render an empty state
/// when the list has no entries.
final List<AppNotification> sampleNotifications = [];
