import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/data_lifecycle_service.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('DataLifecycleService', () {
    late Database db;
    late StepRepository repository;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late DataLifecycleService service;
    var vacuumInvoked = 0;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      userPreferences = UserPreferencesRepository(db);
      vacuumInvoked = 0;
      service = DataLifecycleService(
        db: db,
        databasePath: inMemoryDatabasePath,
        repository: repository,
        userPreferences: userPreferences,
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
      await userPreferences.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      expect(await service.isMaintenanceDue(), isFalse);
    });

    test('isMaintenanceDue returns true after weekly interval elapsed', () async {
      final eightDaysAgo = clock.snapshot().nowUtc.subtract(const Duration(days: 8));
      await userPreferences.setLastDatabaseOptimizedAt(eightDaysAgo);

      expect(await service.isMaintenanceDue(), isTrue);
    });

    test('runMaintenance skips when not due and not forced', () async {
      await userPreferences.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      final result = await service.runMaintenance();

      expect(result.skipped, isTrue);
      expect(result.compaction, isNull);
      expect(vacuumInvoked, 0);
    });

    test('runMaintenance downsamples and records optimization when forced',
        () async {
      await DataInjectService(repository: repository).inject90Days(
        clock: clock,
      );
      await userPreferences.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

      final result = await service.runMaintenance(force: true);

      expect(result.skipped, isFalse);
      expect(result.compaction?.hourlyCreated, 1440);
      expect(await repository.countStepSamples(), 10080);
      expect(vacuumInvoked, 1);
      expect(
        await userPreferences.getLastDatabaseOptimizedAt(),
        clock.snapshot().nowUtc,
      );
    });

    test('runMaintenance runs when due without force', () async {
      await DataInjectService(repository: repository).inject90Days(
        clock: clock,
      );

      final result = await service.runMaintenance();

      expect(result.skipped, isFalse);
      expect(vacuumInvoked, 1);
      expect(await userPreferences.getLastDatabaseOptimizedAt(), isNotNull);
    });
  });
}
