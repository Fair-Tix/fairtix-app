/// The signed-in user's notification choices, stored per user in
/// `public.notification_preferences` and applied by the database function
/// `notify_user()` (supabase/notification_functions.sql). Load and save them
/// through `NotificationPreferencesService`.
///
/// `Ticket & Purchase Updates` and `Event Cancellations & Refunds` are
/// intentionally not exposed as toggles in the UI — they're
/// transactional / time-sensitive notifications (mirrors the `ticket`
/// and `system` NOTIFICATIONS types) that stay on regardless of
/// preference, the same way most ticketing and banking apps don't let
/// you disable purchase or refund alerts.
class NotificationSettings {
  NotificationSettings({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.resaleActivityEnabled = true,
    this.promoEnabled = true,
  });

  /// Push alerts. Off = the server writes no push notification for this user.
  bool pushEnabled;

  /// Email notifications. Off = the server sends no notification emails.
  /// (Sign-in and password codes come from Supabase Auth and are not affected.)
  bool emailEnabled;

  /// Resale listing created / sold / purchase completed. Mirrors the
  /// `resale` NOTIFICATIONS type. Off = no resale notification on any channel.
  bool resaleActivityEnabled;

  /// Promotional announcements from organizers the user has previously
  /// bought from. Mirrors the `promo` NOTIFICATIONS type. Off = none on any
  /// channel.
  bool promoEnabled;

  /// Everything on: what a user with no saved row gets.
  void resetToDefaults() {
    pushEnabled = true;
    emailEnabled = true;
    resaleActivityEnabled = true;
    promoEnabled = true;
  }

  NotificationSettings copy() => NotificationSettings(
        pushEnabled: pushEnabled,
        emailEnabled: emailEnabled,
        resaleActivityEnabled: resaleActivityEnabled,
        promoEnabled: promoEnabled,
      );

  void copyFrom(NotificationSettings other) {
    pushEnabled = other.pushEnabled;
    emailEnabled = other.emailEnabled;
    resaleActivityEnabled = other.resaleActivityEnabled;
    promoEnabled = other.promoEnabled;
  }
}

/// Shared instance holding the signed-in user's choices. Reloaded each time
/// the Notifications settings screen opens.
final NotificationSettings notificationSettings = NotificationSettings();
