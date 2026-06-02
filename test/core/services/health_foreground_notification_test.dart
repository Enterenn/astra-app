import 'package:astra_app/core/services/health_foreground_notification.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthForegroundNotification', () {
    test('uses dedicated channel and id separate from goal notifications', () {
      expect(
        HealthForegroundNotification.channelId,
        isNot(NotificationService.goalChannelId),
      );
      expect(
        HealthForegroundNotification.notificationId,
        isNot(NotificationService.goalNotificationId),
      );
    });

    test('copy is honest health tracking without sync or coach language', () {
      expect(HealthForegroundNotification.title, 'Step tracking active');
      expect(
        HealthForegroundNotification.body,
        'Counting steps in the background on this device.',
      );

      final combined =
          '${HealthForegroundNotification.title} ${HealthForegroundNotification.body}'
              .toLowerCase();
      expect(combined, isNot(contains('sync')));
      expect(combined, isNot(contains('update')));
      expect(combined, isNot(contains('backup')));
    });
  });
}
