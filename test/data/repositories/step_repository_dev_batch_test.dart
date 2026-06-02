import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
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

  group('StepRepository dev batch insert', () {
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

    test('insertDevSamplesBatch inserts all samples in one transaction', () async {
      expect(await repository.countStepSamples(), 0);

      await repository.insertDevSamplesBatch(_sampleBatch(count: 3));

      expect(await repository.countStepSamples(), 3);
    });

    test('countStepSamplesByResolution groups rows by resolution', () async {
      await repository.insertDevSamplesBatch([
        _sample(
          id: '00000000-0000-4000-8000-000000000001',
          resolution: kFiveMinuteResolution,
          startOffsetMinutes: 0,
        ),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          resolution: kFiveMinuteResolution,
          startOffsetMinutes: 5,
        ),
        _sample(
          id: '00000000-0000-4000-8000-000000000003',
          resolution: kHourlyResolution,
          startOffsetMinutes: 10,
        ),
      ]);

      final counts = await repository.countStepSamplesByResolution();

      expect(counts[kFiveMinuteResolution], 2);
      expect(counts[kHourlyResolution], 1);
    });

    test('duplicate UUID is rejected by primary key', () async {
      const duplicateId = '00000000-0000-4000-8000-000000000099';

      await expectLater(
        repository.insertDevSamplesBatch([
          _sample(id: duplicateId, startOffsetMinutes: 0),
          _sample(id: duplicateId, startOffsetMinutes: 5),
        ]),
        throwsA(isA<DatabaseException>()),
      );

      expect(await repository.countStepSamples(), 0);
    });
  });
}

List<TimeseriesSampleModel> _sampleBatch({required int count}) {
  return List.generate(
    count,
    (index) => _sample(
      id: '00000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
      startOffsetMinutes: index * 5,
    ),
  );
}

TimeseriesSampleModel _sample({
  required String id,
  String resolution = kFiveMinuteResolution,
  int startOffsetMinutes = 0,
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
