import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/workmanager_callback.dart';
import 'package:astra_app/core/services/workmanager_tasks.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('runStepCollectionWorkmanagerTask', () {
    late Directory tempDir;
    late String databasePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('astra_wm_task_test_');
      databasePath = '${tempDir.path}${Platform.pathSeparator}astra_test.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes a bucket using an isolate-local database connection', () async {
      final success = await runStepCollectionWorkmanagerTask(
        databasePath: databasePath,
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 17,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
          zoneOffset: const Duration(hours: 2),
        ),
      );

      final uiDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(uiDb.close);
      final repository = StepRepository(
        db: uiDb,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
          zoneOffset: const Duration(hours: 2),
        ),
      );

      expect(success, isTrue);
      expect(
        await repository.getLastIngestionUtc(),
        DateTime.utc(2026, 6, 2, 8, 5),
      );
    });

    test('returns false when collection fails before opening the database', () async {
      final success = await runStepCollectionWorkmanagerTask(
        openDatabase: ({String? databasePath}) async {
          throw StateError('database unavailable');
        },
      );

      expect(success, isFalse);
    });
  });

  group('registerStepCollectionWorkmanager', () {
    test('skips registration on non-Android platforms', () async {
      final client = _FakeWorkmanagerClient();

      await registerStepCollectionWorkmanager(isAndroid: false, client: client);

      expect(client.initialized, isFalse);
      expect(client.registered, isFalse);
    });

    test('initializes and keeps the Android periodic task', () async {
      final client = _FakeWorkmanagerClient();

      await registerStepCollectionWorkmanager(isAndroid: true, client: client);

      expect(client.initialized, isTrue);
      expect(client.callbackDispatcher, same(callbackDispatcher));
      expect(client.registered, isTrue);
      expect(client.uniqueName, kStepCollectionUniqueName);
      expect(client.taskName, kStepCollectionTaskName);
      expect(client.frequency, const Duration(minutes: 15));
      expect(client.existingWorkPolicy, ExistingPeriodicWorkPolicy.keep);
    });
  });
}

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

class _FakeWorkmanagerClient implements StepCollectionWorkmanagerClient {
  bool initialized = false;
  bool registered = false;
  Function? callbackDispatcher;
  String? uniqueName;
  String? taskName;
  Duration? frequency;
  ExistingPeriodicWorkPolicy? existingWorkPolicy;

  @override
  Future<void> initialize(Function callbackDispatcher) async {
    initialized = true;
    this.callbackDispatcher = callbackDispatcher;
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
  }) async {
    registered = true;
    this.uniqueName = uniqueName;
    this.taskName = taskName;
    this.frequency = frequency;
    this.existingWorkPolicy = existingWorkPolicy;
  }
}
