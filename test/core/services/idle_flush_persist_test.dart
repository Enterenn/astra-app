import 'dart:async';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

Future<void> _idleFlushPersist(
  LiveStepMonitor monitor,
  BackgroundCollector collector,
) async {
  await monitor.beginReconcile();
  try {
    await collector.collectOnce(maxReadingsPerSource: 250);
    await monitor.reconcileFromDatabase();
  } finally {
    monitor.endReconcile();
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('idle flush persist', () {
    late Database db;
    late StepTestRepos stepRepos;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;
    late BackgroundCollector collector;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 5, 10),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepAggregation: stepRepos.aggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: const Duration(milliseconds: 200),
      );
      collector = BackgroundCollector(
        sources: [MonitorDrainSource(monitor)],
        normalizer: StepNormalizer(clock: clock),
        repository: stepRepos.ingestion,
        stepAggregation: stepRepos.aggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await events.close();
      await monitor.stop();
      await db.close();
    });

    test('idle flush after live walk never decreases SQLite total', () async {
      const priorBucketSteps = 51;
      const priorBaseline = 80;

      await stepRepos.ingestion.upsertIngestionBucket(
        NormalizedStepBucket(
          startTimeUtc: DateTime.utc(2026, 6, 5, 10),
          endTimeUtc: DateTime.utc(2026, 6, 5, 10, 5),
          value: priorBucketSteps,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      );
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: priorBaseline,
      );

      final persistedBeforeWalk = await stepRepos.aggregation.getTodaySteps();
      expect(persistedBeforeWalk, priorBucketSteps);

      await monitor.start();
      events.add(
        PhoneStepEvent(
          steps: priorBaseline,
          timeStamp: DateTime.utc(2026, 6, 5, 10, 1),
        ),
      );
      events.add(
        PhoneStepEvent(
          steps: 119,
          timeStamp: DateTime.utc(2026, 6, 5, 10, 2),
        ),
      );
      events.add(
        PhoneStepEvent(
          steps: 137,
          timeStamp: DateTime.utc(2026, 6, 5, 10, 3),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final displayBeforeFlush = monitor.currentTodaySteps;
      expect(displayBeforeFlush, greaterThan(persistedBeforeWalk));
      expect(await stepRepos.aggregation.getTodaySteps(), persistedBeforeWalk);

      await _idleFlushPersist(monitor, collector);

      final persistedAfterFlush = await stepRepos.aggregation.getTodaySteps();
      expect(
        persistedAfterFlush,
        greaterThanOrEqualTo(persistedBeforeWalk),
        reason: 'idle flush must not regress SQLite',
      );
      expect(
        monitor.currentTodaySteps,
        greaterThanOrEqualTo(persistedAfterFlush),
      );
      expect(persistedAfterFlush, greaterThan(persistedBeforeWalk));
    });

    test('baseline-gated drain skips readings already credited in baseline', () async {
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 100,
      );
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 90, timeStamp: DateTime.utc(2026, 6, 5, 10)),
      );
      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 5, 10, 1)),
      );
      events.add(
        PhoneStepEvent(steps: 120, timeStamp: DateTime.utc(2026, 6, 5, 10, 2)),
      );
      await Future<void>.delayed(Duration.zero);

      final gated = await monitor.drainReadingsForCollectionGated();

      expect(gated, hasLength(1));
      expect(gated.single.cumulativeSteps, 120);
      expect(monitor.drainReadingsForCollection(), isEmpty);
    });
  });
}
