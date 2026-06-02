import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/fgs_step_collection.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _FakeStepSource implements DataIngestionSource {
  const _FakeStepSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(_readings);
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('runFgsStepCollectionCycle', () {
    late Database db;
    late StepRepository repository;
    final clock = FakeTimeProvider(
      fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
      zoneOffset: const Duration(hours: 2),
    );

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('writes buckets through isolate-safe DB opener', () async {
      final ok = await runFgsStepCollectionCycle(
        openDatabase: ({databasePath}) async => db,
        closeDatabaseOnComplete: false,
        notificationService: _testNotificationService(),
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 10),
            ),
            StepReading(
              cumulativeSteps: 25,
              observedAtUtc: DateTime.utc(2026, 6, 2, 10, 1),
            ),
          ]),
        ],
        clock: clock,
        notificationPermissionGranted: () async => true,
      );

      expect(ok, isTrue);
      expect(
        await repository.getLastIngestionUtc(),
        DateTime.utc(2026, 6, 2, 10, 5),
      );
    });

    test('omits default phone source when UI-active defensive flag set', () async {
      final ok = await runFgsStepCollectionCycle(
        openDatabase: ({databasePath}) async => db,
        closeDatabaseOnComplete: false,
        skipPhoneSourceWhenUiActive: true,
        clock: clock,
        notificationService: _testNotificationService(),
        notificationPermissionGranted: () async => true,
      );

      expect(ok, isTrue);
      expect(await repository.getLastIngestionUtc(), isNull);
    });
  });
}

NotificationService _testNotificationService() {
  return NotificationService(
    goalNotificationPresenter: ({required id, required title, body}) async {},
    permissionChecker: () async => PermissionStatus.granted,
  );
}
