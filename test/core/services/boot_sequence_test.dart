@Tags(['critical'])
library;

import 'dart:async';

import 'package:astra_app/core/services/boot_sequence.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runBootGateBeforeDependencies', () {
    test('starts notification init only after cancel completes', () async {
      final events = <String>[];
      final cancelGate = Completer<void>();

      final gateFuture = runBootGateBeforeDependencies(
        notificationService: NotificationService(),
        cancelStepCollection: () async {
          events.add('cancel-start');
          await cancelGate.future;
          events.add('cancel-done');
        },
        startNotificationInit: (_) async {
          events.add('init');
        },
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, ['cancel-start']);

      cancelGate.complete();
      await gateFuture;

      expect(events, ['cancel-start', 'cancel-done', 'init']);
    });

    test('returns before init completes when init is scheduled in parallel',
        () async {
      final initGate = Completer<void>();
      var initCompleted = false;

      final gateFuture = runBootGateBeforeDependencies(
        notificationService: NotificationService(),
        cancelStepCollection: () async {},
        startNotificationInit: (_) async {
          await initGate.future;
          initCompleted = true;
        },
      );

      await gateFuture;
      expect(initCompleted, isFalse);

      initGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(initCompleted, isTrue);
    });
  });
}
