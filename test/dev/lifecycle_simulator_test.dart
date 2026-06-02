import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/dev/lifecycle_simulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../core/time/fake_time_provider.dart';
import '../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('LifecycleSimulator.simulateDownsampling', () {
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

    test('compacts injected dataset to expected resolution breakdown', () async {
      await DataInjectService(db: db, repository: repository).inject90Days(
        clock: clock,
      );

      final result = await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();

      final counts = await repository.countStepSamplesByResolution();

      expect(result.rowsBefore, 25920);
      expect(result.rowsAfter, 10080);
      expect(counts[kFiveMinuteResolution], 8640);
      expect(counts[kHourlyResolution], 1440);
      expect(counts[kDailyResolution], isNull);
      expect(result.dailyCreated, 0);
    });

    test('preserves total step counts across compaction', () async {
      await DataInjectService(db: db, repository: repository).inject90Days(
        clock: clock,
      );

      final totalBefore = await _sumStepValues(db);

      await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();

      final totalAfter = await _sumStepValues(db);

      expect(totalBefore, greaterThan(0));
      expect(totalAfter, totalBefore);
    });
  });
}

Future<int> _sumStepValues(Database db) async {
  final rows = await db.rawQuery(
    '''
    SELECT SUM(value) AS total
    FROM timeseries_samples
    WHERE type = ?
    ''',
    [kStepSampleType],
  );

  return (rows.single['total'] as num?)?.toInt() ?? 0;
}
