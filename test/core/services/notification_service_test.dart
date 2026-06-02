import 'package:astra_app/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('NotificationService', () {
    test('showGoalReached no-ops when permission denied', () async {
      var showCount = 0;
      final service = NotificationService(
        permissionChecker: () async => PermissionStatus.denied,
        goalNotificationPresenter: ({required id, required title, body}) async {
          showCount += 1;
        },
      );

      await service.showGoalReached();

      expect(showCount, 0);
    });

    test('showGoalReached shows calm copy when permission granted', () async {
      String? shownTitle;
      String? shownBody;
      final service = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
        goalNotificationPresenter: ({required id, required title, body}) async {
          shownTitle = title;
          shownBody = body;
        },
      );

      await service.showGoalReached(stepsToday: 8500);

      expect(shownTitle, NotificationService.goalReachedTitle);
      expect(shownBody, '8500 steps today');
    });

    test('hasNotificationPermission treats limited and provisional as granted', () async {
      final limitedService = NotificationService(
        permissionChecker: () async => PermissionStatus.limited,
      );
      final provisionalService = NotificationService(
        permissionChecker: () async => PermissionStatus.provisional,
      );

      expect(await limitedService.hasNotificationPermission(), isTrue);
      expect(await provisionalService.hasNotificationPermission(), isTrue);
    });

    test('concurrent initialize calls share one platform init', () async {
      var initCount = 0;
      final service = NotificationService(
        platformInitializer: (_) async {
          initCount += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
      );

      await Future.wait([service.initialize(), service.initialize()]);

      expect(initCount, 1);
    });

    test('initializeForBackground returns false when init times out', () async {
      final service = NotificationService(
        platformInitializer: (_) =>
            Future<void>.delayed(const Duration(seconds: 5)),
        backgroundInitTimeout: const Duration(milliseconds: 10),
      );

      expect(await service.initializeForBackground(), isFalse);
    });
  });
}
