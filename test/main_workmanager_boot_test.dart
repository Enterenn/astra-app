import 'package:astra_app/main.dart' as boot;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registerWorkmanagerTasksForBoot', () {
    test('calls step collection before maintenance with databasePath', () async {
      final calls = <String>[];
      const databasePath = '/fake/path/astra_app.db';

      await boot.registerWorkmanagerTasksForBoot(
        databasePath: databasePath,
        registerStepCollection: ({String? databasePath}) async {
          calls.add('step:$databasePath');
        },
        registerMaintenance: ({required String databasePath}) async {
          calls.add('maintenance:$databasePath');
        },
      );

      expect(calls, [
        'step:$databasePath',
        'maintenance:$databasePath',
      ]);
    });

    test('swallows registration errors without rethrow', () async {
      const databasePath = '/fake/path/astra_app.db';

      await boot.registerWorkmanagerTasksForBoot(
        databasePath: databasePath,
        registerStepCollection: ({String? databasePath}) async {
          throw StateError('plugin init failed');
        },
        registerMaintenance: ({required String databasePath}) async {},
      );
    });
  });

  group('schedulePostRunAppWorkmanagerRegistration', () {
    testWidgets('invokes boot registration after first frame', (tester) async {
      const databasePath = '/fake/path/astra_app.db';
      var registerCalled = false;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      boot.schedulePostRunAppWorkmanagerRegistration(
        databasePath,
        registerBoot: ({required String databasePath}) async {
          expect(databasePath, '/fake/path/astra_app.db');
          registerCalled = true;
        },
      );

      expect(registerCalled, isFalse);
      await tester.pump();
      expect(registerCalled, isTrue);
    });
  });
}
