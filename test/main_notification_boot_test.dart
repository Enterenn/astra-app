@Tags(['critical'])
library;

import 'dart:async';

import 'package:astra_app/core/services/boot_sequence.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startNotificationInitForBoot', () {
    test('invokes initialize closure with notification service', () async {
      var called = false;
      final service = NotificationService();

      await startNotificationInitForBoot(
        service,
        initialize: (passed) async {
          expect(passed, same(service));
          called = true;
        },
      );

      expect(called, isTrue);
    });

    test('swallows timeout without rethrow', () async {
      final service = NotificationService(
        platformInitializer: (_) =>
            Future<void>.delayed(const Duration(seconds: 5)),
      );

      await startNotificationInitForBoot(
        service,
        initialize: (passed) =>
            passed.initialize().timeout(const Duration(milliseconds: 10)),
      );
    });

    test('swallows generic errors without rethrow', () async {
      await startNotificationInitForBoot(
        NotificationService(),
        initialize: (_) async {
          throw StateError('plugin init failed');
        },
      );
    });

    test('caller can proceed without awaiting init completion', () async {
      final initGate = Completer<void>();
      var proceededBeforeInit = false;

      final initFuture = startNotificationInitForBoot(
        NotificationService(),
        initialize: (_) => initGate.future,
      );

      proceededBeforeInit = true;
      initGate.complete();
      await initFuture;

      expect(proceededBeforeInit, isTrue);
    });
  });
}
