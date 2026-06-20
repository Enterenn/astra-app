import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/time_provider.dart';
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

  group('StepAggregationRepository.getTodaySteps', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'sums rows for the current local day using each stored offset',
      () async {
        final clock = FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        );
        final stepRepos = StepTestFixtures.create(db: db, clock: clock);
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

        expect(await stepRepos.aggregation.getTodaySteps(), 300);
      },
    );

    test('changes totals when the reference local day changes', () async {
      final writer = StepIngestionRepository(db);
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      await writer.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
          value: 50,
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

      expect(await parisToday.getTodaySteps(), 100);
      expect(await newYorkPreviousDay.getTodaySteps(), 50);
    });

    test(
      'uses a coherent provider snapshot for the reference local day',
      () async {
        await StepIngestionRepository(db).upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
            value: 100,
            zoneOffset: '+02:00',
          ),
        );

        final repository = StepAggregationRepository(
          db,
          clock: _SnapshotOnlyTimeProvider(
            TimeSnapshot(
              nowUtc: DateTime.utc(2026, 6, 2, 10),
              zoneOffset: const Duration(hours: 2),
            ),
          ),
        );

        expect(await repository.getTodaySteps(), 100);
      },
    );

    test('ignores step rows outside the today UTC query window', () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
        zoneOffset: const Duration(hours: 2),
      );
      final stepRepos = StepTestFixtures.create(db: db, clock: clock);
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 42,
          zoneOffset: '+02:00',
        ),
      );
      await stepRepos.ingestion.insertDevSamplesBatch([
        TimeseriesSampleModel.fromNormalizedBucket(
          bucket: _bucket(
            startTimeUtc: DateTime.utc(2026, 1, 1, 8),
            value: 9999,
            zoneOffset: '+02:00',
          ),
          id: 'ancient-noise',
        ),
      ]);

      expect(await stepRepos.aggregation.getTodaySteps(), 42);
    });

    test(
      'uses finest resolution when mixed-resolution rows exist for the same day',
      () async {
        final clock = FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
          zoneOffset: const Duration(hours: 2),
        );
        final stepRepos = StepTestFixtures.create(db: db, clock: clock);
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 6),
            value: 100,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepos.ingestion.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 7),
            value: 50,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepos.ingestion.insertDevSamplesBatch([
          TimeseriesSampleModel(
            id: 'bad-import-hourly',
            startTimeUtc: DateTime.utc(2026, 6, 2, 6),
            endTimeUtc: DateTime.utc(2026, 6, 2, 7),
            type: 'steps',
            value: 300,
            unit: 'steps',
            resolution: '1hour',
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: '+02:00',
          ),
        ]);

        expect(await stepRepos.aggregation.getTodaySteps(), 150);
      },
    );
  });
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

class _SnapshotOnlyTimeProvider implements TimeProvider {
  const _SnapshotOnlyTimeProvider(this._snapshot);

  final TimeSnapshot _snapshot;

  @override
  DateTime nowUtc() => throw StateError('Use snapshot');

  @override
  Duration currentZoneOffset() => throw StateError('Use snapshot');

  @override
  TimeSnapshot snapshot() => _snapshot;
}
