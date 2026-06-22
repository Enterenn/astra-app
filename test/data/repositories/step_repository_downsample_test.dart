import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/lifecycle/sample_compaction_runner.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import '../../dev/data_inject_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepAggregationRepository.downsampleStepSamples', () {
    late Database db;
    late StepTestRepos stepRepos;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('compacts injected 90d dataset to expected row and resolution counts',
        () async {
      await DataInjectService(repository: stepRepos.ingestion).inject90Days(
        clock: clock,
      );

      expect(await stepRepos.aggregation.countStepSamples(), 25920);

      final result = await stepRepos.aggregation.downsampleStepSamples();
      final counts = await stepRepos.aggregation.countStepSamplesByResolution();

      expect(result.hourlyCreated, 1440);
      expect(result.dailyCreated, 0);
      expect(await stepRepos.aggregation.countStepSamples(), 10080);
      expect(counts[kFiveMinuteResolution], 8640);
      expect(counts[kHourlyResolution], 1440);
      expect(counts[kDailyResolution], isNull);
    });

    test('preserves total step value sum across downsampling', () async {
      await DataInjectService(repository: stepRepos.ingestion).inject90Days(
        clock: clock,
      );

      final totalBefore = await _sumStepValues(db);

      await stepRepos.aggregation.downsampleStepSamples();

      final totalAfter = await _sumStepValues(db);

      expect(totalBefore, greaterThan(0));
      expect(totalAfter, totalBefore);
    });

    test('second downsample pass is idempotent when no new data arrives',
        () async {
      await DataInjectService(repository: stepRepos.ingestion).inject90Days(
        clock: clock,
      );

      await stepRepos.aggregation.downsampleStepSamples();
      final countAfterFirst = await stepRepos.aggregation.countStepSamples();

      final secondResult = await stepRepos.aggregation.downsampleStepSamples();

      expect(await stepRepos.aggregation.countStepSamples(), countAfterFirst);
      expect(secondResult.hourlyCreated, 0);
      expect(secondResult.dailyCreated, 0);
    });

    test('accepts external transaction for batched admin writes', () async {
      await DataInjectService(repository: stepRepos.ingestion).inject90Days(
        clock: clock,
      );

      late CompactionResult result;
      await db.transaction((txn) async {
        result = await stepRepos.aggregation.downsampleStepSamples(txn: txn);
      });

      expect(result.hourlyCreated, 1440);
      expect(await stepRepos.aggregation.countStepSamples(), 10080);
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

  return (rows.single['total']! as num).toInt();
}
