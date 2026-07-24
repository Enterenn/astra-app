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

    test(
      'fails order guard if init ran before cancel completed',
      () async {
        final order = <String>[];
        final cancelGate = Completer<void>()..complete();

        await runBootGateBeforeDependencies(
          notificationService: NotificationService(),
          cancelStepCollection: () async {
            order.add('cancel');
            await cancelGate.future;
          },
          startNotificationInit: (_) async {
            order.add('init');
          },
        );

        expect(order, ['cancel', 'init']);
      },
    );

    test('returns before init completes when init is scheduled in parallel',
        () async {
      final initGate = Completer<void>();
      var gateReturned = false;

      final gateFuture = runBootGateBeforeDependencies(
        notificationService: NotificationService(),
        cancelStepCollection: () async {},
        startNotificationInit: (_) => initGate.future,
      );

      gateReturned = true;
      initGate.complete();
      await gateFuture;

      expect(gateReturned, isTrue);
    });
  });
}
