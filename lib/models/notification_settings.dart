/// Placeholder in-memory notification preferences for UI scaffolding.
/// TODO: replace with a real per-user settings document (or persist
/// locally) once the backend is wired up.
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

  /// Push notifications delivered via FCM.
  bool pushEnabled;

  /// Email notifications (OTP, receipts, alerts).
  bool emailEnabled;

  /// Resale listing created / sold / purchase completed. Mirrors the
  /// `resale` NOTIFICATIONS type.
  bool resaleActivityEnabled;

  /// Promotional announcements from organizers the user has previously
  /// bought from. Mirrors the `promo` NOTIFICATIONS type.
  bool promoEnabled;
}

/// Shared mutable settings instance for UI scaffolding, mirroring the
/// pattern used by `currentUser` in `sample_user.dart`.
final NotificationSettings notificationSettings = NotificationSettings();
