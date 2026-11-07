import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_settings.dart';

/// Thrown when notification preferences cannot be loaded or saved.
class NotificationPreferencesException implements Exception {
  final String message;
  const NotificationPreferencesException(this.message);
}

/// Reads and writes the signed-in user's row in `public.notification_preferences`
/// (supabase/notification_preferences.sql). The database function
/// `notify_user()` is what actually applies the choices to in-app, email and
/// push delivery; this service only stores them.
class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final NotificationPreferencesService instance = NotificationPreferencesService._();

  static const String _missingTableHint =
      'Notification preferences are not set up yet: run '
      'supabase/notification_preferences.sql in the Supabase SQL Editor.';

  /// Loads the user's saved choices into [notificationSettings]. No row yet
  /// means the user never changed anything, so every switch stays on.
  Future<void> load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      notificationSettings.resetToDefaults();
      return;
    }
    try {
      final row = await client
          .from('notification_preferences')
          .select('email_enabled, push_enabled, resale_enabled, promo_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        notificationSettings.resetToDefaults();
        return;
      }
      notificationSettings
        ..emailEnabled = (row['email_enabled'] as bool?) ?? true
        ..pushEnabled = (row['push_enabled'] as bool?) ?? true
        ..resaleActivityEnabled = (row['resale_enabled'] as bool?) ?? true
        ..promoEnabled = (row['promo_enabled'] as bool?) ?? true;
    } on PostgrestException catch (e) {
      throw NotificationPreferencesException(_message(e));
    }
  }

  /// Saves the four switches for the signed-in user.
  Future<void> save(NotificationSettings settings) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const NotificationPreferencesException(
        'Your session has expired. Please log in again.',
      );
    }
    try {
      await client.from('notification_preferences').upsert({
        'user_id': userId,
        'email_enabled': settings.emailEnabled,
        'push_enabled': settings.pushEnabled,
        'resale_enabled': settings.resaleActivityEnabled,
        'promo_enabled': settings.promoEnabled,
      });
    } on PostgrestException catch (e) {
      throw NotificationPreferencesException(_message(e));
    }
  }

  String _message(PostgrestException e) {
    // 42P01 = table missing, PGRST205 = not in the API schema cache.
    if (e.code == '42P01' || e.code == 'PGRST205') return _missingTableHint;
    return 'Could not reach your notification settings: ${e.message}';
  }
}
