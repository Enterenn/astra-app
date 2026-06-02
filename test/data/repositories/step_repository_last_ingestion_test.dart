import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepRepository.getLastIngestionUtc', () {
    late Database db;
    late StepRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
          zoneOffset: const Duration(hours: 2),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns null when there are no step samples', () async {
      expect(await repository.getLastIngestionUtc(), isNull);
    });

    test('returns the latest UTC end time for step samples only', () async {
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
        ),
      );
      await repository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 10),
        ),
      );
      await db.insert('timeseries_samples', {
        'id': '00000000-0000-4000-8000-000000000123',
        'start_time': '2026-06-02T09:00:00Z',
        'end_time': '2026-06-02T09:05:00Z',
        'type': 'heart_rate',
        'value': 70,
        'unit': 'bpm',
        'resolution': kFiveMinuteResolution,
        'provider': kInternalPhoneProvider,
        'device_id': kSmartphoneDeviceId,
        'zone_offset': '+02:00',
      });

      expect(
        await repository.getLastIngestionUtc(),
        DateTime.utc(2026, 6, 2, 8, 10),
      );
    });
  });
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required DateTime endTimeUtc,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: endTimeUtc,
  value: 100,
  provider: kInternalPhoneProvider,
  deviceId: kSmartphoneDeviceId,
  zoneOffset: '+02:00',
);
