@Tags(['slow'])
library;

import 'dart:async';

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

      expect(await service.showGoalReached(), isFalse);
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

      expect(await service.showGoalReached(stepsToday: 8500), isTrue);
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

    test('background init timeout ignores late platform init for _initialized', () async {
      var initCount = 0;
      final initCompleter = Completer<void>();
      final service = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
        platformInitializer: (_) async {
          initCount++;
          if (initCount == 1) {
            await initCompleter.future;
          }
        },
        backgroundInitTimeout: const Duration(milliseconds: 10),
      );

      expect(await service.initializeForBackground(), isFalse);
      initCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(await service.initializeForBackground(), isTrue);
      expect(initCount, 2);
    });

    test('background init timeout ignores late stale init failure for retry', () async {
      var initCount = 0;
      final staleInitGate = Completer<void>();
      final service = NotificationService(
        platformInitializer: (_) async {
          initCount++;
          if (initCount == 1) {
            await staleInitGate.future;
            throw StateError('stale init failed');
          }
        },
        backgroundInitTimeout: const Duration(milliseconds: 10),
      );

      expect(await service.initializeForBackground(), isFalse);

      final retryFuture = service.initializeForBackground();
      staleInitGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(await retryFuture, isTrue);
      expect(initCount, 2);
    });

    test('initializeForBackground returns false when init fails', () async {
      final service = NotificationService(
        platformInitializer: (_) async => throw StateError('plugin init failed'),
      );

      expect(await service.initializeForBackground(), isFalse);
    });

    test('initialize rethrows when platform init fails', () async {
      final service = NotificationService(
        platformInitializer: (_) async => throw StateError('plugin init failed'),
      );

      await expectLater(
        service.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('failed init clears state so second initialize retries', () async {
      var initCount = 0;
      final service = NotificationService(
        platformInitializer: (_) async {
          initCount += 1;
          if (initCount == 1) {
            throw StateError('plugin init failed');
          }
        },
      );

      await expectLater(
        service.initialize(),
        throwsA(isA<StateError>()),
      );
      await service.initialize();

      expect(initCount, 2);
    });

    test('showGoalReached returns false when init fails', () async {
      final service = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
        platformInitializer: (_) async => throw StateError('plugin init failed'),
      );

      expect(await service.showGoalReached(), isFalse);
    });
  });
}
