import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
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

  group('StepRepository.exportCsv', () {
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
      tempDir = await Directory.systemTemp.createTemp('astra_export_');
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test('empty DB writes header-only CSV with dated filename', () async {
      final filePath = await repository.exportCsv(outputDirectory: tempDir.path);

      expect(p.basename(filePath), 'astra-export-2026-06-03.csv');
      expect(File(filePath).existsSync(), isTrue);

      final lines = await File(filePath).readAsLines();
      expect(lines, [TimeseriesCsvCodec.headerRow]);
    });

    test('exported row count and ids match injected samples byte-for-byte', () async {
      const ids = [
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        'c3d4e5f6-a7b8-9012-cdef-123456789012',
      ];

      await repository.insertDevSamplesBatch([
        _sample(
          id: ids[0],
          startOffsetMinutes: 0,
          resolution: kFiveMinuteResolution,
        ),
        _sample(
          id: ids[1],
          startOffsetMinutes: 5,
          resolution: kHourlyResolution,
        ),
        _sample(
          id: ids[2],
          startOffsetMinutes: 10,
          resolution: kDailyResolution,
        ),
      ]);

      final filePath = await repository.exportCsv(outputDirectory: tempDir.path);
      final lines = await File(filePath).readAsLines();

      expect(lines.length, 4);
      expect(lines.first, TimeseriesCsvCodec.headerRow);

      final exportedIds = lines.skip(1).map((line) => line.split(',').first);
      expect(exportedIds, ids);

      final dbRows = await db.query(
        'timeseries_samples',
        where: 'type = ?',
        whereArgs: [kStepSampleType],
        orderBy: 'start_time ASC',
      );
      for (var i = 0; i < dbRows.length; i++) {
        final sample = TimeseriesSampleModel.fromMap(dbRows[i]);
        expect(lines[i + 1], TimeseriesCsvCodec.serializeRow(sample));
      }
    });

    test('export includes all resolutions after compaction mix', () async {
      await repository.insertDevSamplesBatch([
        _sample(
          id: '00000000-0000-4000-8000-000000000001',
          resolution: kFiveMinuteResolution,
        ),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          resolution: kHourlyResolution,
        ),
      ]);

      final filePath = await repository.exportCsv(outputDirectory: tempDir.path);
      final content = await File(filePath).readAsString();

      expect(content, contains(',5min,'));
      expect(content, contains(',1hour,'));
    });
  });
}

TimeseriesSampleModel _sample({
  required String id,
  int startOffsetMinutes = 0,
  String resolution = kFiveMinuteResolution,
}) {
  final start = DateTime.utc(2026, 6, 2, 8, startOffsetMinutes);
  return TimeseriesSampleModel(
    id: id,
    startTimeUtc: start,
    endTimeUtc: start.add(const Duration(minutes: 5)),
    type: kStepSampleType,
    value: 100,
    unit: kStepSampleUnit,
    resolution: resolution,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: '+02:00',
  );
}
