import '../../data/repositories/user_preferences_repository.dart';
import '../services/notification_service.dart';

/// One-time upgrade: users who granted OS notification permission before the
/// Profile toggle existed should keep receiving goal notifications.
Future<void> migrateGoalNotificationPreferenceIfNeeded({
  required UserPreferencesRepository userPreferences,
  required NotificationService notificationService,
}) async {
  if (await userPreferences.isGoalNotificationsPreferenceSet()) {
    return;
  }
  if (await notificationService.hasNotificationPermission()) {
    await userPreferences.setGoalNotificationsEnabled(true);
  }
}
