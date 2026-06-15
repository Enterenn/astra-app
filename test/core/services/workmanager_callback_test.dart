import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/core/services/data_lifecycle_service.dart';
import 'package:astra_app/core/services/workmanager_callback.dart';
import 'package:astra_app/core/services/workmanager_tasks.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/core/time/local_day_formatter.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
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
        notificationService: _testNotificationService(),
        notificationPermissionGranted: () async => true,
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

    test('evaluates goal notification when WM bootstrap crosses goal', () async {
      var showCount = 0;
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      final notificationService = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
        goalNotificationPresenter: ({required id, required title, body}) async {
          showCount += 1;
        },
      );

      final uiDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(uiDb.close);
      final userPreferences = UserPreferencesRepository(uiDb, clock: clock);
      await userPreferences.setDailyStepGoal(5000);
      await userPreferences.setGoalNotificationsEnabled(true);
      final repository = StepRepository(db: uiDb, clock: clock);
      await repository.upsertIngestionBucket(
        NormalizedStepBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 6),
          endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
          value: 4900,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      );
      await uiDb.close();

      final success = await runStepCollectionWorkmanagerTask(
        databasePath: databasePath,
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 200,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
        clock: clock,
        notificationService: notificationService,
        notificationPermissionGranted: () async => true,
      );

      final verifyDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(verifyDb.close);
      final verifyPrefs = UserPreferencesRepository(verifyDb);

      expect(success, isTrue);
      expect(showCount, 1);
      expect(
        await verifyPrefs.getGoalNotificationShownDate(),
        formatLocalDayIso(clock.snapshot()),
      );
      expect(await verifyPrefs.getCelebrationShownDate(), isNull);
    });

    test(
      'FGS-unavailable bootstrap uses phone provider only without monitor drain',
      () async {
        final success = await runStepCollectionWorkmanagerTask(
          databasePath: databasePath,
          notificationService: _testNotificationService(),
          notificationPermissionGranted: () async => false,
          sources: [
            _FakeStepSource([
              StepReading(
                cumulativeSteps: 5,
                observedAtUtc: DateTime.utc(2026, 6, 2, 8),
              ),
            ]),
          ],
          clock: FakeTimeProvider(
            fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
            zoneOffset: const Duration(hours: 2),
          ),
        );

        expect(success, isTrue);
      },
    );

    test(
      'skips goal notification when background init times out but still collects',
      () async {
        final clock = FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
          zoneOffset: const Duration(hours: 2),
        );
        final notificationService = NotificationService(
          platformInitializer: (_) =>
              Future<void>.delayed(const Duration(seconds: 5)),
          backgroundInitTimeout: const Duration(milliseconds: 10),
          permissionChecker: () async => PermissionStatus.granted,
        );

        final uiDb = await openAstraDatabase(databasePath: databasePath);
        addTearDown(uiDb.close);
        final userPreferences = UserPreferencesRepository(uiDb, clock: clock);
        await userPreferences.setDailyStepGoal(5000);
        await userPreferences.setGoalNotificationsEnabled(true);
        final repository = StepRepository(db: uiDb, clock: clock);
        await repository.upsertIngestionBucket(
          NormalizedStepBucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 6),
            endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
            value: 4900,
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: '+02:00',
          ),
        );
        await uiDb.close();

        final success = await runStepCollectionWorkmanagerTask(
          databasePath: databasePath,
          sources: [
            _FakeStepSource([
              StepReading(
                cumulativeSteps: 10,
                observedAtUtc: DateTime.utc(2026, 6, 2, 8),
              ),
              StepReading(
                cumulativeSteps: 200,
                observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
              ),
            ]),
          ],
          clock: clock,
          notificationService: notificationService,
          notificationPermissionGranted: () async => true,
        );

        final verifyDb = await openAstraDatabase(databasePath: databasePath);
        addTearDown(verifyDb.close);
        final verifyPrefs = UserPreferencesRepository(verifyDb);

        expect(success, isTrue);
        expect(await verifyPrefs.getGoalNotificationShownDate(), isNull);
      },
    );

    test('returns false when collection fails before opening the database', () async {
      final success = await runStepCollectionWorkmanagerTask(
        openDatabase: ({String? databasePath}) async {
          throw StateError('database unavailable');
        },
      );

      expect(success, isFalse);
    });
  });

  group('runDatabaseMaintenanceWorkmanagerTask', () {
    late Directory tempDir;
    late String databasePath;
    late FakeTimeProvider clock;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('astra_wm_maint_test_');
      databasePath = '${tempDir.path}${Platform.pathSeparator}astra_maint.db';
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downsamples injected data when maintenance is due', () async {
      final seedDb = await openAstraDatabase(databasePath: databasePath);
      final repository = StepRepository(db: seedDb, clock: clock);
      await DataInjectService(repository: repository).inject90Days(clock: clock);
      await seedDb.close();

      final success = await runDatabaseMaintenanceWorkmanagerTask(
        databasePath: databasePath,
        clock: clock,
      );

      final verifyDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(verifyDb.close);
      final verifyRepository = StepRepository(db: verifyDb, clock: clock);
      final verifyPrefs = UserPreferencesRepository(verifyDb);

      expect(success, isTrue);
      expect(await verifyRepository.countStepSamples(), 10080);
      expect(await verifyPrefs.getLastDatabaseOptimizedAt(), isNotNull);
    });

    test('skips compaction when maintenance is not due', () async {
      final seedDb = await openAstraDatabase(databasePath: databasePath);
      final repository = StepRepository(db: seedDb, clock: clock);
      await DataInjectService(repository: repository).inject90Days(clock: clock);
      final prefs = UserPreferencesRepository(seedDb);
      await prefs.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);
      await seedDb.close();

      LifecycleRunResult? captured;
      final success = await runDatabaseMaintenanceWorkmanagerTask(
        databasePath: databasePath,
        clock: clock,
        runMaintenance: (service) async {
          captured = await service.runMaintenance();
          return captured!;
        },
      );

      final verifyDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(verifyDb.close);
      final verifyRepository = StepRepository(db: verifyDb, clock: clock);

      expect(success, isTrue);
      expect(captured!.skipped, isTrue);
      expect(await verifyRepository.countStepSamples(), 25920);
    });

    test('returns false when databasePath is missing', () async {
      expect(
        await runDatabaseMaintenanceWorkmanagerTask(),
        isFalse,
      );
    });
  });

  group('registerDatabaseMaintenanceWorkmanager', () {
    test('skips registration on non-Android platforms', () async {
      final client = _FakeWorkmanagerClient();

      await registerDatabaseMaintenanceWorkmanager(
        isAndroid: false,
        databasePath: '/tmp/astra.db',
        client: client,
      );

      expect(client.registered, isFalse);
    });

    test('registers weekly maintenance with databasePath inputData', () async {
      final client = _FakeWorkmanagerClient();
      await registerDatabaseMaintenanceWorkmanager(
        isAndroid: true,
        databasePath: '/data/user/0/com.astraapp/databases/astra_app.db',
        client: client,
      );

      expect(client.initialized, isTrue);
      expect(client.uniqueName, kDatabaseMaintenanceUniqueName);
      expect(client.taskName, kDatabaseMaintenanceTaskName);
      expect(client.frequency, kDatabaseMaintenanceInterval);
      expect(client.existingWorkPolicy, ExistingPeriodicWorkPolicy.update);
      expect(
        client.inputData,
        {'databasePath': '/data/user/0/com.astraapp/databases/astra_app.db'},
      );
    });
  });

  group('cancelStepCollectionWorkmanager', () {
    test('skips cancel on non-Android platforms', () async {
      final client = _FakeWorkmanagerClient();

      await cancelStepCollectionWorkmanager(isAndroid: false, client: client);

      expect(client.cancelledUniqueName, isNull);
    });

    test('cancels the Android periodic unique name', () async {
      final client = _FakeWorkmanagerClient();

      await cancelStepCollectionWorkmanager(isAndroid: true, client: client);

      expect(client.cancelledUniqueName, kStepCollectionUniqueName);
    });
  });

  group('registerStepCollectionWorkmanager', () {
    test('skips registration on non-Android platforms', () async {
      final client = _FakeWorkmanagerClient();

      await registerStepCollectionWorkmanager(isAndroid: false, client: client);

      expect(client.initialized, isFalse);
      expect(client.registered, isFalse);
    });

    test('initializes and keeps the Android periodic task without inputData', () async {
      final client = _FakeWorkmanagerClient();

      await registerStepCollectionWorkmanager(isAndroid: true, client: client);

      expect(client.initialized, isTrue);
      expect(client.callbackDispatcher, same(callbackDispatcher));
      expect(client.registered, isTrue);
      expect(client.uniqueName, kStepCollectionUniqueName);
      expect(client.taskName, kStepCollectionTaskName);
      expect(client.frequency, const Duration(minutes: 15));
      expect(client.existingWorkPolicy, ExistingPeriodicWorkPolicy.keep);
      expect(client.inputData, isNull);
    });

    test(
      'registers with databasePath inputData when FGS would be unavailable',
      () async {
        final client = _FakeWorkmanagerClient();

        await registerStepCollectionWorkmanager(
          isAndroid: true,
          databasePath: '/data/user/0/com.astraapp/databases/astra_app.db',
          client: client,
        );

        expect(client.registered, isTrue);
        expect(
          client.inputData,
          {'databasePath': '/data/user/0/com.astraapp/databases/astra_app.db'},
        );
        expect(client.existingWorkPolicy, ExistingPeriodicWorkPolicy.update);
      },
    );

    test(
      'still registers on Android when activity permission denied (FGS skipped)',
      () async {
        final client = _FakeWorkmanagerClient();

        await registerStepCollectionWorkmanager(isAndroid: true, client: client);

        expect(client.registered, isTrue);
      },
    );
  });
}

NotificationService _testNotificationService() {
  return NotificationService(
    goalNotificationPresenter: ({required id, required title, body}) async {},
    permissionChecker: () async => PermissionStatus.granted,
  );
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
  String? cancelledUniqueName;

  @override
  Future<void> initialize(Function callbackDispatcher) async {
    initialized = true;
    this.callbackDispatcher = callbackDispatcher;
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelledUniqueName = uniqueName;
  }

  Map<String, dynamic>? inputData;

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
    Map<String, dynamic>? inputData,
  }) async {
    registered = true;
    this.uniqueName = uniqueName;
    this.taskName = taskName;
    this.frequency = frequency;
    this.existingWorkPolicy = existingWorkPolicy;
    this.inputData = inputData;
  }
}
