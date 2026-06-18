import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/csv/import_validation_exception.dart';
import 'package:astra_app/data/csv/timeseries_csv_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepRepository.importCsv', () {
    late Database db;
    late StepRepository repository;
    late FakeTimeProvider clock;
    late Directory tempDir;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 10),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      tempDir = await Directory.systemTemp.createTemp('astra_import_');
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<String> writeCsvFile(List<String> lines) async {
      final file = File(p.join(tempDir.path, 'import.csv'));
      await file.writeAsString(lines.join('\n'));
      return file.path;
    }

    test('export then import into empty DB inserts all rows', () async {
      await repository.insertDevSamplesBatch([
        _sample(id: '00000000-0000-4000-8000-000000000001'),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          startOffsetMinutes: 5,
        ),
      ]);

      final exportPath = await repository.exportCsv(outputDirectory: tempDir.path);
      await db.delete('timeseries_samples');

      final result = await repository.importCsv(filePath: exportPath);

      expect(result.totalRowsInFile, 2);
      expect(result.insertedCount, 2);
      expect(result.skippedCount, 0);
      expect(await repository.countStepSamples(), 2);
    });

    test('re-import same file skips all rows', () async {
      await repository.insertDevSamplesBatch([
        _sample(id: '00000000-0000-4000-8000-000000000001'),
      ]);
      final exportPath = await repository.exportCsv(outputDirectory: tempDir.path);

      final result = await repository.importCsv(filePath: exportPath);

      expect(result.insertedCount, 0);
      expect(result.skippedCount, 1);
      expect(result.totalRowsInFile, 1);
    });

    test('malformed CSV throws and leaves DB unchanged', () async {
      await repository.insertDevSamplesBatch([
        _sample(id: '00000000-0000-4000-8000-000000000001'),
      ]);
      final before = await repository.countStepSamples();

      final path = await writeCsvFile([
        TimeseriesCsvCodec.headerRow,
        'bad-row',
      ]);

      expect(
        () => repository.importCsv(filePath: path),
        throwsA(isA<ImportValidationException>()),
      );
      expect(await repository.countStepSamples(), before);
    });

    test('duplicate bucket identity with new UUID increments skippedCount', () async {
      await repository.insertDevSamplesBatch([
        _sample(id: '00000000-0000-4000-8000-000000000001'),
      ]);

      final duplicateBucketRow = TimeseriesCsvCodec.serializeRow(
        _sample(id: '00000000-0000-4000-8000-000000000099'),
      );
      final path = await writeCsvFile([
        TimeseriesCsvCodec.headerRow,
        duplicateBucketRow,
      ]);

      final result = await repository.importCsv(filePath: path);

      expect(result.insertedCount, 0);
      expect(result.skippedCount, 1);
      expect(await repository.countStepSamples(), 1);
    });

    test('header-only CSV is a no-op import', () async {
      final path = await writeCsvFile([TimeseriesCsvCodec.headerRow]);

      final result = await repository.importCsv(filePath: path);

      expect(result.totalRowsInFile, 0);
      expect(result.insertedCount, 0);
      expect(result.skippedCount, 0);
    });

    test('export purge import round-trip preserves base36 ids from ingestion', () async {
      await repository.upsertIngestionBucket(
        _ingestionBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 100,
        ),
      );
      await repository.upsertIngestionBucket(
        _ingestionBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
          value: 42,
        ),
      );

      final idsBeforeExport = await _sampleIds(db);
      expect(idsBeforeExport, hasLength(2));
      for (final id in idsBeforeExport) {
        expect(
          id,
          isNot(
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false,
              ),
            ),
          ),
        );
      }

      final exportPath = await repository.exportCsv(outputDirectory: tempDir.path);
      await repository.purge();
      expect(await repository.countStepSamples(), 0);

      final result = await repository.importCsv(filePath: exportPath);

      expect(result.totalRowsInFile, 2);
      expect(result.insertedCount, 2);
      expect(result.skippedCount, 0);
      expect(await repository.countStepSamples(), 2);
      expect(await _sampleIds(db), idsBeforeExport);
    });

    test('round-trip restores chart daily aggregates', () async {
      final samples = [
        _sample(
          id: '00000000-0000-4000-8000-000000000001',
          startOffsetMinutes: 0,
          value: 50,
        ),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          startOffsetMinutes: 60,
          value: 75,
        ),
      ];
      await repository.insertDevSamplesBatch(samples);

      final before = await repository.getChartDailyAggregates(days: 7);
      final exportPath = await repository.exportCsv(outputDirectory: tempDir.path);
      await db.delete('timeseries_samples');
      expect(await repository.countStepSamples(), 0);

      await repository.importCsv(filePath: exportPath);

      final after = await repository.getChartDailyAggregates(days: 7);
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].localDay, before[i].localDay);
        expect(after[i].totalSteps, before[i].totalSteps);
      }
    });
  });
}

Future<List<String>> _sampleIds(Database db) async {
  final rows = await db.query(
    'timeseries_samples',
    columns: ['id'],
    orderBy: 'start_time ASC',
  );
  return rows.map((row) => row['id']! as String).toList();
}

NormalizedStepBucket _ingestionBucket({
  required DateTime startTimeUtc,
  required int value,
}) {
  return NormalizedStepBucket(
    startTimeUtc: startTimeUtc,
    endTimeUtc: startTimeUtc.add(const Duration(minutes: 5)),
    value: value,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: '+02:00',
  );
}

TimeseriesSampleModel _sample({
  required String id,
  int startOffsetMinutes = 0,
  int value = 100,
}) {
  final start = DateTime.utc(2026, 6, 2, 8, startOffsetMinutes);
  return TimeseriesSampleModel(
    id: id,
    startTimeUtc: start,
    endTimeUtc: start.add(const Duration(minutes: 5)),
    type: kStepSampleType,
    value: value,
    unit: kStepSampleUnit,
    resolution: kFiveMinuteResolution,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: '+02:00',
  );
}
