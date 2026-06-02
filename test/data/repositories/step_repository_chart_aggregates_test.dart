import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/dev/lifecycle_simulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepRepository.getChartDailyAggregates', () {
    late Database db;
    late FakeTimeProvider clock;
    late StepRepository repository;

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

    test('returns 7 or 30 items with positive totals on 90-day inject', () async {
      await DataInjectService(repository: repository).inject90Days(clock: clock);

      final sevenDay = await repository.getChartDailyAggregates(days: 7);
      final thirtyDay = await repository.getChartDailyAggregates(days: 30);

      expect(sevenDay, hasLength(7));
      expect(thirtyDay, hasLength(30));
      expect(sevenDay.every((entry) => entry.totalSteps > 0), isTrue);
      expect(thirtyDay.every((entry) => entry.totalSteps > 0), isTrue);
    });

    test('7-day window boundaries align with reference today', () async {
      await DataInjectService(repository: repository).inject90Days(clock: clock);

      final aggregates = await repository.getChartDailyAggregates(days: 7);
      final referenceToday = DateTime.utc(2026, 6, 2);
      final windowStart = referenceToday.subtract(const Duration(days: 6));

      expect(aggregates.first.localDay, referenceToday);
      expect(aggregates.last.localDay, windowStart);
      expect(
        aggregates.every(
          (entry) =>
              !entry.localDay.isBefore(windowStart) &&
              !entry.localDay.isAfter(referenceToday),
        ),
        isTrue,
      );
    });

    test('groups mixed zone offsets into correct local day buckets', () async {
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 50,
          zoneOffset: '-05:00',
          provider: 'adp_ble',
          deviceId: 'ring',
        ),
      );
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 200,
          zoneOffset: '+02:00',
        ),
      );

      final aggregates = await repository.getChartDailyAggregates(days: 7);

      expect(aggregates, hasLength(7));
      expect(
        aggregates.firstWhere((entry) => entry.localDay == DateTime.utc(2026, 6, 2)).totalSteps,
        300,
      );
      expect(
        aggregates.firstWhere((entry) => entry.localDay == DateTime.utc(2026, 6, 1)).totalSteps,
        50,
      );
      expect(
        aggregates.firstWhere((entry) => entry.localDay == DateTime.utc(2026, 5, 31)).totalSteps,
        0,
      );
    });

    test('preserves 7-day daily totals after lifecycle compaction', () async {
      await DataInjectService(repository: repository).inject90Days(clock: clock);

      final before = await repository.getChartDailyAggregates(days: 7);

      await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();

      final after = await repository.getChartDailyAggregates(days: 7);

      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(after[i].localDay, before[i].localDay);
        expect(after[i].totalSteps, before[i].totalSteps);
      }
    });

    test('returns zero-filled entries when no samples exist', () async {
      final sevenDay = await repository.getChartDailyAggregates(days: 7);
      final thirtyDay = await repository.getChartDailyAggregates(days: 30);

      expect(sevenDay, hasLength(7));
      expect(thirtyDay, hasLength(30));
      expect(sevenDay.every((entry) => entry.totalSteps == 0), isTrue);
      expect(thirtyDay.every((entry) => entry.totalSteps == 0), isTrue);
    });

    test('throws ArgumentError for unsupported day ranges', () async {
      await expectLater(
        repository.getChartDailyAggregates(days: 14),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required int value,
  required String zoneOffset,
  String provider = kInternalPhoneProvider,
  String deviceId = kSmartphoneDeviceId,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: startTimeUtc.add(const Duration(minutes: 5)),
  value: value,
  provider: provider,
  deviceId: deviceId,
  zoneOffset: zoneOffset,
);
