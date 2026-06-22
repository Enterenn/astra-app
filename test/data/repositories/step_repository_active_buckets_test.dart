import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepAggregationRepository.getTodayActiveBuckets', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns only 5min buckets for today with value > 0', () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
        zoneOffset: const Duration(hours: 2),
      );
      final stepRepos = StepTestFixtures.create(db: db, clock: clock);

      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 9),
          value: 200,
          zoneOffset: '+02:00',
          resolution: kHourlyResolution,
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 8),
          value: 50,
          zoneOffset: '+02:00',
        ),
      );
      await stepRepos.ingestion.insertDevSamplesBatch([
        TimeseriesSampleModel.fromNormalizedBucket(
          bucket: _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 0,
            zoneOffset: '+02:00',
          ),
          id: 'zero-bucket',
        ),
      ]);

      final buckets = await stepRepos.aggregation.getTodayActiveBuckets();

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 100);
      expect(buckets.single.resolution, kFiveMinuteResolution);
    });

    test('excludes cross-day rows using stored zone offset', () async {
      final writer = StepIngestionRepository(db);
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 80,
          zoneOffset: '+02:00',
        ),
      );
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 60,
          zoneOffset: '-05:00',
          provider: 'adp_ble',
          deviceId: 'ring',
        ),
      );

      final parisToday = StepAggregationRepository(
        db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        ),
      );
      final newYorkPreviousDay = StepAggregationRepository(
        db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 2),
          zoneOffset: const Duration(hours: -5),
        ),
      );

      expect((await parisToday.getTodayActiveBuckets()).single.value, 80);
      expect((await newYorkPreviousDay.getTodayActiveBuckets()).single.value, 60);
    });
  });

  group('StepAggregationRepository.getActiveBucketsForLocalDay', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns buckets for parameter day and excludes other days', () async {
      final writer = StepIngestionRepository(db);
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 10),
          value: 80,
          zoneOffset: '+02:00',
        ),
      );
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 120,
          zoneOffset: '+02:00',
        ),
      );

      final reader = StepAggregationRepository(
        db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        ),
      );

      final monday = DateTime(2026, 6, 1);
      final tuesday = DateTime(2026, 6, 2);
      final mondayBuckets = await reader.getActiveBucketsForLocalDay(monday);
      final tuesdayBuckets = await reader.getActiveBucketsForLocalDay(tuesday);

      expect(mondayBuckets, hasLength(1));
      expect(mondayBuckets.single.value, 80);
      expect(tuesdayBuckets, hasLength(1));
      expect(tuesdayBuckets.single.value, 120);
    });
  });
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required int value,
  required String zoneOffset,
  String provider = kInternalPhoneProvider,
  String deviceId = kSmartphoneDeviceId,
  String resolution = kFiveMinuteResolution,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: startTimeUtc.add(
    resolution == kFiveMinuteResolution
        ? const Duration(minutes: 5)
        : const Duration(hours: 1),
  ),
  value: value,
  provider: provider,
  deviceId: deviceId,
  zoneOffset: zoneOffset,
  resolution: resolution,
);
