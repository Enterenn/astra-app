import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../core/time/fake_time_provider.dart';
import '../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('DataInjectService.inject90Days', () {
    late Database db;
    late StepRepository repository;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('writes 25920 canonical step samples with unique UUIDs', () async {
      final result = await DataInjectService(
        db: db,
        repository: repository,
      ).inject90Days(clock: clock);

      expect(result.daysInjected, 90);
      expect(result.bucketsInserted, 25920);
      expect(result.anchorUtc, clock.snapshot().nowUtc);
      expect(await repository.countStepSamples(), 25920);

      final rows = await db.query('timeseries_samples');
      final ids = rows.map((row) => row['id']! as String).toSet();

      expect(rows, hasLength(25920));
      expect(ids, hasLength(25920));

      for (final row in rows) {
        expect(row['type'], kStepSampleType);
        expect(row['resolution'], kFiveMinuteResolution);
        expect(row['unit'], kStepSampleUnit);
        final value = row['value']! as num;
        expect(value, greaterThanOrEqualTo(0));
        expect(value, equals(value.round()));
      }
    });

    test('clears existing step samples before re-injecting', () async {
      final service = DataInjectService(db: db, repository: repository);

      await service.inject90Days(clock: clock);
      await service.inject90Days(clock: clock);

      expect(await repository.countStepSamples(), 25920);
    });

    test('does not delete non-step rows when clearing before inject', () async {
      await db.insert('user_preferences', {
        'key': 'test_pref',
        'value': 'keep-me',
      });

      await DataInjectService(db: db, repository: repository).inject90Days(
        clock: clock,
      );

      final prefs = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: ['test_pref'],
      );

      expect(prefs, hasLength(1));
      expect(prefs.single['value'], 'keep-me');
    });
  });
}
