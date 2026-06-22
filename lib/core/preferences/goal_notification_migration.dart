import '../../data/repositories/user_settings_repository.dart';
import '../services/notification_service.dart';

/// One-time upgrade: users who granted OS notification permission before the
/// Profile toggle existed should keep receiving goal notifications.
Future<void> migrateGoalNotificationPreferenceIfNeeded({
  required UserSettingsRepository userSettings,
  required NotificationService notificationService,
}) async {
  if (await userSettings.isGoalNotificationsPreferenceSet()) {
    return;
  }
  if (await notificationService.hasNotificationPermission()) {
    await userSettings.setGoalNotificationsEnabled(true);
  }
}
