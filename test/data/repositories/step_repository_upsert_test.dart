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

  group('StepRepository.upsertIngestionBucket', () {
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

    test('inserts a normalized step bucket as a timeseries sample', () async {
      await repository.upsertIngestionBucket(_bucket(value: 100));

      final rows = await db.query('timeseries_samples');

      expect(rows, hasLength(1));
      expect(rows.single['id'], isA<String>());
      expect(rows.single['start_time'], '2026-06-02T08:00:00Z');
      expect(rows.single['end_time'], '2026-06-02T08:05:00Z');
      expect(rows.single['type'], kStepSampleType);
      expect(rows.single['value'], 100);
      expect(rows.single['zone_offset'], '+02:00');
    });

    test('updates duplicate bucket value without replacing the id', () async {
      await repository.upsertIngestionBucket(_bucket(value: 100));
      final originalRows = await db.query('timeseries_samples');
      final originalId = originalRows.single['id'];

      await repository.upsertIngestionBucket(_bucket(value: 175));

      final rows = await db.query('timeseries_samples');
      expect(rows, hasLength(1));
      expect(rows.single['id'], originalId);
      expect(rows.single['value'], 175);
    });

    test('database rejects negative step values', () async {
      await expectLater(
        db.insert('timeseries_samples', {
          'id': '00000000-0000-4000-8000-000000000099',
          'start_time': '2026-06-02T08:00:00Z',
          'end_time': '2026-06-02T08:05:00Z',
          'type': kStepSampleType,
          'value': -1,
          'unit': kStepSampleUnit,
          'resolution': kFiveMinuteResolution,
          'provider': kInternalPhoneProvider,
          'device_id': kSmartphoneDeviceId,
          'zone_offset': '+02:00',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}

NormalizedStepBucket _bucket({required int value}) => NormalizedStepBucket(
  startTimeUtc: DateTime.utc(2026, 6, 2, 8),
  endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
  value: value,
  provider: kInternalPhoneProvider,
  deviceId: kSmartphoneDeviceId,
  zoneOffset: '+02:00',
);
