import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepRepository.getTodayActiveBuckets', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns only 5min buckets for today with value > 0', () async {
      final repository = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        ),
      );

      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 9),
          value: 200,
          zoneOffset: '+02:00',
          resolution: kHourlyResolution,
        ),
      );
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 8),
          value: 50,
          zoneOffset: '+02:00',
        ),
      );
      await repository.insertDevSamplesBatch([
        TimeseriesSampleModel.fromNormalizedBucket(
          bucket: _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 0,
            zoneOffset: '+02:00',
          ),
          id: 'zero-bucket',
        ),
      ]);

      final buckets = await repository.getTodayActiveBuckets();

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 100);
      expect(buckets.single.resolution, kFiveMinuteResolution);
    });

    test('excludes cross-day rows using stored zone offset', () async {
      final writer = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        ),
      );
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

      final parisToday = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        ),
      );
      final newYorkPreviousDay = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 2),
          zoneOffset: const Duration(hours: -5),
        ),
      );

      expect((await parisToday.getTodayActiveBuckets()).single.value, 80);
      expect((await newYorkPreviousDay.getTodayActiveBuckets()).single.value, 60);
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
