import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
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

  group('StepAggregationRepository.getChartMonthlyAggregates', () {
    late Database db;
    late FakeTimeProvider clock;
    late StepTestRepos stepRepos;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 15, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns 12 items for rolling window ending in current month', () async {
      await DataInjectService(repository: stepRepos.ingestion).inject90Days(clock: clock);

      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);

      expect(aggregates, hasLength(12));
      expect(aggregates.first.monthStart, DateTime.utc(2026, 6, 1));
      expect(aggregates.last.monthStart, DateTime.utc(2025, 7, 1));
      _expectSortedNewestFirst(aggregates);
    });

    test('partial current month uses elapsed days as denominator', () async {
      for (var day = 1; day <= 10; day++) {
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, day, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
      }

      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);
      final june = aggregates.firstWhere(
        (entry) => entry.monthStart == DateTime.utc(2026, 6, 1),
      );

      expect(june.totalSteps, 10_000);
      expect(june.dayCount, 15);
      expect(june.averageDailySteps, (10_000 / 15).round());
    });

    test('complete past month uses full calendar day count', () async {
      for (var day = 1; day <= 31; day++) {
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 5, day, 10),
            value: 100,
            zoneOffset: '+02:00',
          ),
        );
      }

      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);
      final may = aggregates.firstWhere(
        (entry) => entry.monthStart == DateTime.utc(2026, 5, 1),
      );

      expect(may.totalSteps, 3100);
      expect(may.dayCount, 31);
      expect(may.averageDailySteps, 100);
    });

    test('months with zero steps render as zero averages', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 500,
          zoneOffset: '+02:00',
        ),
      );

      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);
      final may = aggregates.firstWhere(
        (entry) => entry.monthStart == DateTime.utc(2026, 5, 1),
      );

      expect(may.totalSteps, 0);
      expect(may.averageDailySteps, 0);
      expect(may.dayCount, 31);
    });

    test('groups mixed zone offsets into correct local day buckets', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 50,
          zoneOffset: '-05:00',
          provider: 'adp_ble',
          deviceId: 'ring',
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 200,
          zoneOffset: '+02:00',
        ),
      );

      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);
      final june = aggregates.firstWhere(
        (entry) => entry.monthStart == DateTime.utc(2026, 6, 1),
      );

      expect(june.totalSteps, 350);
    });

    test(
      'uses finest resolution when mixed-resolution rows exist for the same day',
      () async {
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 8),
            value: 120,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 9),
            value: 80,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepos.ingestion.insertDevSamplesBatch([
          TimeseriesSampleModel(
            id: 'bad-import-hourly',
            startTimeUtc: DateTime.utc(2026, 6, 1, 8),
            endTimeUtc: DateTime.utc(2026, 6, 1, 9),
            type: 'steps',
            value: 500,
            unit: 'steps',
            resolution: '1hour',
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: '+02:00',
          ),
        ]);

        final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);
        final june = aggregates.firstWhere(
          (entry) => entry.monthStart == DateTime.utc(2026, 6, 1),
        );

        expect(june.totalSteps, 200);
      },
    );

    test('returns zero-filled months when no samples exist', () async {
      final aggregates = await stepRepos.aggregation.getChartMonthlyAggregates(months: 12);

      expect(aggregates, hasLength(12));
      expect(aggregates.every((entry) => entry.totalSteps == 0), isTrue);
      expect(aggregates.every((entry) => entry.averageDailySteps == 0), isTrue);
      expect(aggregates.first.dayCount, 15);
      expect(
        aggregates.firstWhere(
          (entry) => entry.monthStart == DateTime.utc(2026, 5, 1),
        ).dayCount,
        31,
      );
    });

    test('throws ArgumentError for unsupported month ranges', () async {
      await expectLater(
        stepRepos.aggregation.getChartMonthlyAggregates(months: 6),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

void _expectSortedNewestFirst(List<ChartMonthAggregate> aggregates) {
  for (var i = 0; i < aggregates.length - 1; i++) {
    expect(
      aggregates[i].monthStart.isAfter(aggregates[i + 1].monthStart),
      isTrue,
    );
  }
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
