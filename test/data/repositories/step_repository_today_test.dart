import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/time_provider.dart';
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

  group('StepRepository.getTodaySteps', () {
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
        final repository = StepRepository(
          db: db,
          clock: FakeTimeProvider(
            fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
            zoneOffset: const Duration(hours: 2),
          ),
        );
        await repository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
            value: 100,
            zoneOffset: '+02:00',
          ),
        );
        await repository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
            value: 50,
            zoneOffset: '-05:00',
            provider: 'adp_ble',
            deviceId: 'ring',
          ),
        );
        await repository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 200,
            zoneOffset: '+02:00',
          ),
        );

        expect(await repository.getTodaySteps(), 300);
      },
    );

    test('changes totals when the reference local day changes', () async {
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

      expect(await parisToday.getTodaySteps(), 100);
      expect(await newYorkPreviousDay.getTodaySteps(), 50);
    });

    test(
      'uses a coherent provider snapshot for the reference local day',
      () async {
        await StepRepository(
          db: db,
          clock: FakeTimeProvider(
            fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
            zoneOffset: const Duration(hours: 2),
          ),
        ).upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 22, 30),
            value: 100,
            zoneOffset: '+02:00',
          ),
        );

        final repository = StepRepository(
          db: db,
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
