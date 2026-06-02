import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('BackgroundCollector', () {
    late Database db;
    late StepRepository repository;
    late StepNormalizer normalizer;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      normalizer = StepNormalizer(clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('normalizes source readings, upserts buckets, and fires callback', () async {
      var callbackCount = 0;
      final collector = BackgroundCollector(
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
            StepReading(
              cumulativeSteps: 30,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 6),
            ),
          ]),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      )..registerOnIngestionComplete(() => callbackCount += 1);

      final upsertedCount = await collector.collectOnce();

      final rows = await db.query(
        'timeseries_samples',
        orderBy: 'start_time ASC',
      );
      expect(upsertedCount, 2);
      expect(callbackCount, 1);
      expect(rows, hasLength(2));
      expect(rows.first['value'], 5);
      expect(rows.last['value'], 15);
    });

    test('skips sources that emit no readings', () async {
      var callbackCount = 0;
      final collector = BackgroundCollector(
        sources: [_FakeStepSource(const [])],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      )..registerOnIngestionComplete(() => callbackCount += 1);

      expect(await collector.collectOnce(), 0);
      expect(callbackCount, 0);
      expect(await db.query('timeseries_samples'), isEmpty);
    });

    test('catches source errors and continues with remaining sources', () async {
      final collector = BackgroundCollector(
        sources: [
          _ThrowingStepSource(),
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      );

      expect(await collector.collectOnce(), 1);
      expect(await db.query('timeseries_samples'), hasLength(1));
    });

    test('writes a bucket from one reading when a persisted baseline exists', () async {
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 5000,
      );
      final collector = BackgroundCollector(
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 5100,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
          ]),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      );

      expect(await collector.collectOnce(), 1);
      expect(await db.query('timeseries_samples'), hasLength(1));
      expect(
        await baselineRepository.getBaseline(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
        ),
        5100,
      );
    });

    test('skips overlapping collectOnce calls while one is in flight', () async {
      final collector = BackgroundCollector(
        sources: [
          _SlowStepSource(
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(seconds: 1),
      );

      final first = collector.collectOnce();
      final second = collector.collectOnce();
      expect(await second, 0);
      expect(await first, 1);
    });

    test('returns when a live source emits no events', () async {
      final collector = BackgroundCollector(
        sources: [_NeverEmittingStepSource()],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      );

      expect(await collector.collectOnce(), 0);
      expect(await db.query('timeseries_samples'), isEmpty);
    });

    test('registerOnIngestionComplete can be set after construction', () async {
      var callbackCount = 0;
      final collector = BackgroundCollector(
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      );

      collector.registerOnIngestionComplete(() => callbackCount += 1);

      expect(await collector.collectOnce(), 1);
      expect(callbackCount, 1);
    });

    test('clearing registered callback prevents further invocations', () async {
      var callbackCount = 0;
      final collector = BackgroundCollector(
        sources: [
          _FakeStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
        normalizer: normalizer,
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 10),
      )..registerOnIngestionComplete(() => callbackCount += 1);

      collector.registerOnIngestionComplete(null);

      expect(await collector.collectOnce(), 1);
      expect(callbackCount, 0);
    });
  });
}

class _FakeStepSource implements DataIngestionSource {
  const _FakeStepSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(_readings);
}

class _ThrowingStepSource implements DataIngestionSource {
  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => 'throwing';

  @override
  Stream<StepReading> watchStepReadings() async* {
    throw StateError('sensor unavailable');
  }
}

class _SlowStepSource implements DataIngestionSource {
  _SlowStepSource(this.first, this.second);

  final StepReading first;
  final StepReading second;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() async* {
    yield first;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield second;
  }
}

class _NeverEmittingStepSource implements DataIngestionSource {
  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => 'never';

  @override
  Stream<StepReading> watchStepReadings() => Stream<StepReading>.multi((_) {});
}
