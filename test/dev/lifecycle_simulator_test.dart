import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/timestamp_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/dev/lifecycle_compaction.dart';
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
      await DataInjectService(repository: repository).inject90Days(
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
      await DataInjectService(repository: repository).inject90Days(
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

    test('skips incomplete hour groups without merging across gaps', () async {
      await DataInjectService(repository: repository).inject90Days(
        clock: clock,
      );

      final referenceNowUtc = clock.snapshot().nowUtc;
      const referenceZoneOffset = '+02:00';
      final rows = await db.query(
        'timeseries_samples',
        where: 'resolution = ?',
        whereArgs: [kFiveMinuteResolution],
      );

      final tierTwoRow = rows.firstWhere((row) {
        final startTimeUtc = TimestampCodec.parseUtc(row['start_time']! as String);
        return isTierTwoFiveMinuteSample(
          referenceNowUtc: referenceNowUtc,
          referenceZoneOffset: referenceZoneOffset,
          startTimeUtc: startTimeUtc,
          sampleZoneOffset: row['zone_offset']! as String,
        );
      });

      await db.delete(
        'timeseries_samples',
        where: 'id = ?',
        whereArgs: [tierTwoRow['id']],
      );

      final totalBefore = await _sumStepValues(db);

      await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();

      final totalAfter = await _sumStepValues(db);
      final counts = await repository.countStepSamplesByResolution();

      expect(totalAfter, totalBefore);
      expect(counts[kFiveMinuteResolution], 8651);
    });

    test('compacts orphaned 5-minute rows aged past tier 3 to daily', () async {
      const zoneOffset = '+02:00';
      final referenceNow = DateTime.utc(2026, 6, 2, 12);
      final oldLocalDay = DateTime.utc(2025, 5, 1);

      for (var bucketIndex = 0; bucketIndex < 288; bucketIndex++) {
        final minuteOffset = bucketIndex * 5;
        final hour = minuteOffset ~/ 60;
        final minute = minuteOffset % 60;
        final localInstant = DateTime.utc(
          oldLocalDay.year,
          oldLocalDay.month,
          oldLocalDay.day,
          hour,
          minute,
        );
        final startTimeUtc = localInstant.subtract(const Duration(hours: 2));
        final endTimeUtc = startTimeUtc.add(const Duration(minutes: 5));

        await db.insert('timeseries_samples', {
          'id': '00000000-0000-4000-8000-${bucketIndex.toString().padLeft(12, '0')}',
          'start_time': TimestampCodec.formatUtc(startTimeUtc),
          'end_time': TimestampCodec.formatUtc(endTimeUtc),
          'type': kStepSampleType,
          'value': 10,
          'unit': kStepSampleUnit,
          'resolution': kFiveMinuteResolution,
          'provider': kInternalPhoneProvider,
          'device_id': kSmartphoneDeviceId,
          'zone_offset': zoneOffset,
        });
      }

      final result = await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: FakeTimeProvider(
          fixedNowUtc: referenceNow,
          zoneOffset: const Duration(hours: 2),
        ),
      ).simulateDownsampling();

      final counts = await repository.countStepSamplesByResolution();

      expect(result.dailyCreated, 1);
      expect(counts[kDailyResolution], 1);
      expect(counts[kFiveMinuteResolution], isNull);
      expect(await _sumStepValues(db), 2880);
    });
  });

  group('runDevLifecycleSimulate', () {
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

    test('delegates to simulateDownsampling in debug builds', () async {
      await DataInjectService(repository: repository).inject90Days(
        clock: clock,
      );

      final result = await runDevLifecycleSimulate(
        db: db,
        repository: repository,
        clock: clock,
      );

      expect(result.rowsBefore, 25920);
      expect(result.rowsAfter, 10080);
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
