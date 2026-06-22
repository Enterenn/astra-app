import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/data_lifecycle_service.dart';

import 'package:astra_app/data/repositories/user_settings_repository.dart';
import '../../dev/data_inject_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('DataLifecycleService', () {
    late Database db;
    late StepIngestionRepository stepIngestion;
    late StepAggregationRepository repository;
    late UserSettingsRepository userSettings;
    late FakeTimeProvider clock;
    late DataLifecycleService service;
    var vacuumInvoked = 0;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepIngestion = StepIngestionRepository(db);
      repository = StepAggregationRepository(db, clock: clock);
      userSettings = UserSettingsRepository(db);
      vacuumInvoked = 0;
      service = DataLifecycleService(
        db: db,
        databasePath: inMemoryDatabasePath,
        repository: repository,
        userSettings: userSettings,
        clock: clock,
        optimizeAndVacuum: (_, _) async {
          vacuumInvoked++;
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('isMaintenanceDue returns true when last optimized is missing', () async {
      expect(await service.isMaintenanceDue(), isTrue);
    });

    test('isMaintenanceDue returns false within weekly interval', () async {
      await userSettings.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      expect(await service.isMaintenanceDue(), isFalse);
    });

    test('isMaintenanceDue returns true after weekly interval elapsed', () async {
      final eightDaysAgo = clock.snapshot().nowUtc.subtract(const Duration(days: 8));
      await userSettings.setLastDatabaseOptimizedAt(eightDaysAgo);

      expect(await service.isMaintenanceDue(), isTrue);
    });

    test('runMaintenance skips when not due and not forced', () async {
      await userSettings.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      final result = await service.runMaintenance();

      expect(result.skipped, isTrue);
      expect(result.compaction, isNull);
      expect(vacuumInvoked, 0);
    });

    test('runMaintenance downsamples and records optimization when forced',
        () async {
      await DataInjectService(repository: stepIngestion).inject90Days(
        clock: clock,
      );
      await userSettings.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      final result = await service.runMaintenance(force: true);

      expect(result.skipped, isFalse);
      expect(result.compaction?.hourlyCreated, 1440);
      expect(await repository.countStepSamples(), 10080);
      expect(vacuumInvoked, 1);
      expect(
        await userSettings.getLastDatabaseOptimizedAt(),
        clock.snapshot().nowUtc,
      );
    });

    test('runMaintenance runs when due without force', () async {
      await DataInjectService(repository: stepIngestion).inject90Days(
        clock: clock,
      );

      final result = await service.runMaintenance();

      expect(result.skipped, isFalse);
      expect(vacuumInvoked, 1);
      expect(await userSettings.getLastDatabaseOptimizedAt(), isNotNull);
    });

    test('concurrent runMaintenance executes a single maintenance pass', () async {
      var vacuumInProgress = false;
      var vacuumPasses = 0;

      service = DataLifecycleService(
        db: db,
        databasePath: inMemoryDatabasePath,
        repository: repository,
        userSettings: userSettings,
        clock: clock,
        optimizeAndVacuum: (_, _) async {
          expect(vacuumInProgress, isFalse);
          vacuumInProgress = true;
          vacuumPasses++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          vacuumInProgress = false;
        },
      );

      await DataInjectService(repository: stepIngestion).inject90Days(
        clock: clock,
      );

      final results = await Future.wait([
        service.runMaintenance(force: true),
        service.runMaintenance(force: true),
      ]);

      expect(vacuumPasses, 1);
      expect(results.every((r) => !r.skipped), isTrue);
      expect(results.first.compaction?.hourlyCreated, 1440);
    });
  });

  group('bounded growth (file database)', () {
    late Directory tempDir;
    late String databasePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('astra_lifecycle_growth_');
      databasePath = '${tempDir.path}${Platform.pathSeparator}astra.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'two maintenance passes keep row count stable and file size bounded',
      () async {
        final clock = FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
          zoneOffset: const Duration(hours: 2),
        );
        final db = await openAstraDatabase(databasePath: databasePath);
        addTearDown(db.close);
        final stepIngestion = StepIngestionRepository(db);
        final repository = StepAggregationRepository(db, clock: clock);
        final service = DataLifecycleService(
          db: db,
          databasePath: databasePath,
          repository: repository,
          userSettings: UserSettingsRepository(db),
          clock: clock,
          maintenanceOnCurrentConnection: true,
          optimizeAndVacuum: runPragmaOptimizeAndVacuumOnWorkerIsolate,
        );

        await DataInjectService(repository: stepIngestion).inject90Days(
          clock: clock,
        );

        await service.runMaintenance(force: true);
        final rowsAfterFirst = await repository.countStepSamples();
        final sizeAfterFirst = File(databasePath).lengthSync();

        await service.runMaintenance(force: true);
        final rowsAfterSecond = await repository.countStepSamples();
        final sizeAfterSecond = File(databasePath).lengthSync();

        expect(rowsAfterFirst, 10080);
        expect(rowsAfterSecond, rowsAfterFirst);
        expect(
          sizeAfterSecond,
          lessThanOrEqualTo(sizeAfterFirst + 65536),
        );
      },
    );

    test('second maintenance compaction creates no new hourly or daily rows',
        () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      addTearDown(db.close);
      final stepIngestion2 = StepIngestionRepository(db);
      final repository = StepAggregationRepository(db, clock: clock);
      final service = DataLifecycleService(
        db: db,
        databasePath: inMemoryDatabasePath,
        repository: repository,
        userSettings: UserSettingsRepository(db),
        clock: clock,
        optimizeAndVacuum: (_, _) async {},
      );

      await DataInjectService(repository: stepIngestion2).inject90Days(
        clock: clock,
      );

      final first = await service.runMaintenance(force: true);
      final second = await service.runMaintenance(force: true);

      expect(first.compaction!.hourlyCreated, 1440);
      expect(second.compaction!.hourlyCreated, 0);
      expect(second.compaction!.dailyCreated, 0);
      expect(await repository.countStepSamples(), 10080);
    });

    test('runMaintenanceOnConnection compacts exclusive file connection',
        () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final db = await openAstraDatabase(databasePath: databasePath);
      addTearDown(db.close);
      final stepIngestion3 = StepIngestionRepository(db);
      final repository = StepAggregationRepository(db, clock: clock);
      final userSettings = UserSettingsRepository(db);

      await DataInjectService(repository: stepIngestion3).inject90Days(
        clock: clock,
      );

      final result = await runMaintenanceOnConnection(
        db: db,
        databasePath: databasePath,
        repository: repository,
        userSettings: userSettings,
        clock: clock,
        force: true,
      );

      expect(result.skipped, isFalse);
      expect(result.compaction?.hourlyCreated, 1440);
      expect(await repository.countStepSamples(), 10080);
    });
  });
}
