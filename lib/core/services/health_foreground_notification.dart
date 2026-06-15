/// Android health FGS notification — separate from goal notifications (Story 2.7).
///
/// UX §3.12: honest ongoing copy; never disguised as sync or backup.
class HealthForegroundNotification {
  HealthForegroundNotification._();

  static const String channelId = 'astra_health_tracking';
  static const String channelName = 'Step tracking';
  static const int notificationId = 100;

  static const String title = 'Tracking steps';
  static const String body =
      'Background step count on this device.';
}
