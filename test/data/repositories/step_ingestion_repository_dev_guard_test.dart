@Tags(['critical'])
library;

import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepIngestionRepository.insertDevSamplesBatch dev guard', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts one row in debug/test builds', () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
        zoneOffset: const Duration(hours: 2),
      );
      final stepRepos = StepTestFixtures.create(db: db, clock: clock);
      final start = DateTime.utc(2026, 6, 2, 8);

      await stepRepos.ingestion.insertDevSamplesBatch([
        TimeseriesSampleModel(
          id: 'dev-guard-smoke',
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(minutes: 5)),
          type: kStepSampleType,
          value: 42,
          unit: kStepSampleUnit,
          resolution: kFiveMinuteResolution,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      ]);

      final rows = await db.query(
        'timeseries_samples',
        where: 'id = ?',
        whereArgs: ['dev-guard-smoke'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['value'], 42);
    });

    test('source uses runtime kDebugMode guard, not assert wrapper', () {
      final source = File(
        'lib/data/repositories/step/step_ingestion_repository.dart',
      ).readAsStringSync();

      expect(source, contains('if (!kDebugMode)'));
      expect(source, isNot(contains('assert(() {')));
    });
  });
}
