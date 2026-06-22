import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepAggregationRepository.getFootprint', () {
    late Database db;
    late StepTestRepos stepRepos;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns zero count and zero file size for empty in-memory DB', () async {
      final footprint = await stepRepos.aggregation.getFootprint(
        databasePath: inMemoryDatabasePath,
      );

      expect(footprint.sampleCount, 0);
      expect(footprint.fileSizeBytes, 0);
    });

    test('sample count matches injected step samples', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 10),
        ),
      );

      final footprint = await stepRepos.aggregation.getFootprint(
        databasePath: inMemoryDatabasePath,
      );

      expect(footprint.sampleCount, 2);
      expect(footprint.fileSizeBytes, 0);
    });

    test('file size is greater than zero for on-disk database file', () async {
      final tempDir = await Directory.systemTemp.createTemp('astra_footprint_');
      final databasePath = p.join(tempDir.path, 'astra_footprint_test.db');

      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final fileDb = await openAstraDatabase(databasePath: databasePath);
      final fileStepRepos = StepTestFixtures.create(db: fileDb, clock: clock);

      await fileStepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
        ),
      );

      final footprint = await fileStepRepos.aggregation.getFootprint(
        databasePath: databasePath,
      );

      expect(footprint.sampleCount, 1);
      expect(footprint.fileSizeBytes, greaterThan(0));

      await fileDb.close();
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
