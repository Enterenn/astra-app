@Tags(['slow'])
library;

import 'dart:async';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/contracts/step_aggregation_repository_contract.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/data/models/database_footprint.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';

class _CountingStepAggregation implements StepAggregationRepositoryContract {
  _CountingStepAggregation(this.clock, {this.stubbedSteps = 0});

  @override
  final TimeProvider clock;

  final int stubbedSteps;
  int getTodayStepsCallCount = 0;

  @override
  Future<int> getTodaySteps() async {
    getTodayStepsCallCount++;
    return stubbedSteps;
  }

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async => [];

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<DateTime?> getLastIngestionUtc() async => null;

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

Future<void> _persistBufferedSteps(
  LiveStepMonitor monitor,
  BackgroundCollector collector, {
  void Function()? onComplete,
}) async {
  await monitor.beginReconcile();
  try {
    await collector.collectOnce(maxReadingsPerSource: 250);
    await monitor.reconcileFromDatabase();
  } finally {
    monitor.endReconcile();
    onComplete?.call();
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('LiveStepMonitor', () {
    late Database db;
    late StepAggregationRepository stepAggregation;
    late StepIngestionRepository stepIngestion;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepAggregation = StepAggregationRepository(db, clock: clock);
      stepIngestion = StepIngestionRepository(db);
      baselineRepository = IngestionBaselineRepository(db);
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
    });

    tearDown(() async {
      await monitor.dispose();
      await events.close();
      await db.close();
    });

    test('replays current value to new subscribers', () async {
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 25, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);

      final values = <int>[];
      final sub = monitor.watchTodaySteps().listen(values.add);
      await Future<void>.delayed(Duration.zero);

      expect(values.first, 15);
      await sub.cancel();
    });

    test('reconcileFromDatabase loads persisted today steps', () async {
      final normalizer = StepNormalizer(clock: clock);
      final collector = BackgroundCollector(
        sources: [MonitorDrainSource(monitor)],
        normalizer: normalizer,
        repository: stepIngestion,
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );

      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 50, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 70, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);

      await monitor.beginReconcile();
      await collector.collectOnce(maxReadingsPerSource: 250);
      await monitor.reconcileFromDatabase();
      monitor.endReconcile();

      expect(await stepAggregation.getTodaySteps(), 20);
      expect(monitor.currentTodaySteps, 20);
    });

    test('reconcile never lowers displayed total when SQLite lags', () async {
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 171, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 71);

      await monitor.reconcileFromDatabase();

      expect(monitor.currentTodaySteps, greaterThanOrEqualTo(71));
    });

    test(
      'forwards hardware reset readings through baseline-gated drain',
      () async {
        await baselineRepository.setBaseline(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          cumulative: 10_000,
        );
        await monitor.start();
        events.add(
          PhoneStepEvent(steps: 50, timeStamp: DateTime.utc(2026, 6, 2, 12)),
        );
        events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
        );
        events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 12, 2)),
        );
        await Future<void>.delayed(Duration.zero);

        final gated = await monitor.drainReadingsForCollectionGated();

        expect(gated, hasLength(3));
        expect(
          gated.map((r) => r.cumulativeSteps).toList(),
          [50, 100, 150],
        );
        expect(monitor.drainReadingsForCollection(), isEmpty);
      },
    );

    test(
      'drops noise dip above reset threshold in baseline-gated drain',
      () async {
        await baselineRepository.setBaseline(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          cumulative: 10_000,
        );
        await monitor.start();
        events.add(
          PhoneStepEvent(steps: 9900, timeStamp: DateTime.utc(2026, 6, 2, 12)),
        );
        await Future<void>.delayed(Duration.zero);

        final gated = await monitor.drainReadingsForCollectionGated();

        expect(gated, isEmpty);
        expect(monitor.drainReadingsForCollection(), isEmpty);
      },
    );

    test('drainReadingsForCollection empties the full buffer', () async {
      await monitor.start();
      for (var i = 1; i <= 60; i++) {
        events.add(
          PhoneStepEvent(
            steps: i,
            timeStamp: DateTime.utc(2026, 6, 2, 12, i % 60),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);

      final drained = monitor.drainReadingsForCollection();
      expect(drained, hasLength(60));
      expect(monitor.drainReadingsForCollection(), isEmpty);
    });

    test('collect during active monitor drains buffer without second stream', () async {
      var streamListenCount = 0;
      final countingMonitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () {
          streamListenCount += 1;
          return events.stream;
        },
        emitThrottle: Duration.zero,
      );

      await countingMonitor.start();
      events.add(
        PhoneStepEvent(steps: 5, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 12, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);

      final collector = BackgroundCollector(
        sources: [MonitorDrainSource(countingMonitor)],
        normalizer: StepNormalizer(clock: clock),
        repository: stepIngestion,
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );

      await countingMonitor.beginReconcile();
      await collector.collectOnce(maxReadingsPerSource: 250);
      await countingMonitor.reconcileFromDatabase();
      countingMonitor.endReconcile();

      expect(streamListenCount, 1);
      await countingMonitor.dispose();
    });

    test('endReconcile flushes buffered readings to live display', () async {
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 50, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      await Future<void>.delayed(Duration.zero);

      await monitor.beginReconcile();
      events.add(
        PhoneStepEvent(steps: 80, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 0);

      monitor.endReconcile();
      expect(monitor.currentTodaySteps, 30);
    });

    test('rate-limits shake burst so pending delta does not jump by full hardware delta', () async {
      await monitor.start();
      await monitor.reconcileFromDatabase();

      final t0 = DateTime.utc(2026, 6, 2, 12);
      events.add(PhoneStepEvent(steps: 1000, timeStamp: t0));
      events.add(
        PhoneStepEvent(
          steps: 1050,
          timeStamp: t0.add(const Duration(milliseconds: 200)),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(monitor.currentTodaySteps, 1);
    });

    test('activity idle fires after delay with no new readings', () async {
      var idleCount = 0;
      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: const Duration(milliseconds: 100),
        onActivityIdle: () => idleCount++,
      );

      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 25, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(idleCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(idleCount, 1);
    });

    test('new reading cancels pending activity idle timer', () async {
      var idleCount = 0;
      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: const Duration(milliseconds: 100),
        onActivityIdle: () => idleCount++,
      );

      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      events.add(
        PhoneStepEvent(steps: 20, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(idleCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(idleCount, 1);
    });

    test('activity idle triggers persist cycle without lifecycle pause', () async {
      const idleDelay = Duration(milliseconds: 100);
      final persistDone = Completer<void>();
      final normalizer = StepNormalizer(clock: clock);

      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: idleDelay,
      );
      final collector = BackgroundCollector(
        sources: [MonitorDrainSource(monitor)],
        normalizer: normalizer,
        repository: stepIngestion,
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );
      monitor.onActivityIdle = () {
        unawaited(
          _persistBufferedSteps(
            monitor,
            collector,
            onComplete: persistDone.complete,
          ),
        );
      };

      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 100);
      expect(await stepAggregation.getTodaySteps(), 0);

      await Future<void>.delayed(idleDelay);
      await persistDone.future;
      expect(await stepAggregation.getTodaySteps(), 100);
    });

    test('stop cancels activity idle timer', () async {
      var idleCount = 0;
      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: const Duration(milliseconds: 50),
        onActivityIdle: () => idleCount++,
      );

      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      await Future<void>.delayed(Duration.zero);
      await monitor.stop();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(idleCount, 0);
    });

    test('peekPhoneStepEvent reads hardware while monitor is stopped', () async {
      final replay = [
        PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 2, 12, 5)),
      ];
      final peekMonitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () async* {
          for (final event in replay) {
            yield event;
          }
          yield* events.stream;
        },
        emitThrottle: Duration.zero,
      );

      final peeked = await peekMonitor.peekPhoneStepEvent();
      expect(peeked?.steps, 200);
      await peekMonitor.dispose();
    });

    test('stop and start re-subscribes and preserves monotonic display', () async {
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 50, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 80, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 30);

      await monitor.stop();
      await monitor.start();
      await monitor.reconcileFromDatabase();
      expect(monitor.isRunning, isTrue);
      expect(monitor.currentTodaySteps, greaterThanOrEqualTo(30));

      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12, 2)),
      );
      events.add(
        PhoneStepEvent(steps: 130, timeStamp: DateTime.utc(2026, 6, 2, 12, 3)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, greaterThan(30));
    });

    group('seed API (AUD-03 dedup)', () {
      late _CountingStepAggregation countingAggregation;
      late LiveStepMonitor seedMonitor;

      setUp(() {
        countingAggregation = _CountingStepAggregation(clock, stubbedSteps: 500);
        seedMonitor = LiveStepMonitor(
          stepAggregation: countingAggregation,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () => events.stream,
          emitThrottle: Duration.zero,
        );
      });

      tearDown(() async {
        await seedMonitor.dispose();
      });

      test('start(seedPersistedSteps) skips getTodaySteps and initializes to seed', () async {
        await seedMonitor.start(seedPersistedSteps: 42);

        expect(countingAggregation.getTodayStepsCallCount, 0);
        expect(seedMonitor.currentTodaySteps, 42);
      });

      test('reconcileFromDatabase(seedPersistedSteps) skips getTodaySteps', () async {
        await seedMonitor.start(seedPersistedSteps: 42);
        countingAggregation.getTodayStepsCallCount = 0;

        await seedMonitor.reconcileFromDatabase(seedPersistedSteps: 42);

        expect(countingAggregation.getTodayStepsCallCount, 0);
        expect(seedMonitor.currentTodaySteps, 42);
      });

      test('unseeded start() reads DB (regression guard)', () async {
        await seedMonitor.start();

        expect(countingAggregation.getTodayStepsCallCount, 1);
        expect(seedMonitor.currentTodaySteps, 500);
      });

      test('unseeded reconcileFromDatabase() reads DB (regression guard)', () async {
        await seedMonitor.start(seedPersistedSteps: 42);
        countingAggregation.getTodayStepsCallCount = 0;

        await seedMonitor.reconcileFromDatabase();

        expect(countingAggregation.getTodayStepsCallCount, 1);
        expect(seedMonitor.currentTodaySteps, 500);
      });

      test('seeded reconcile preserves live overlay when seed is stale', () async {
        await seedMonitor.start(seedPersistedSteps: 100);
        events.add(
          PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 2, 12)),
        );
        events.add(
          PhoneStepEvent(steps: 271, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
        );
        await Future<void>.delayed(Duration.zero);
        final liveTotal = seedMonitor.currentTodaySteps;
        expect(liveTotal, 171);

        countingAggregation.getTodayStepsCallCount = 0;
        await seedMonitor.reconcileFromDatabase(seedPersistedSteps: 100);

        expect(countingAggregation.getTodayStepsCallCount, 0);
        expect(seedMonitor.currentTodaySteps, greaterThanOrEqualTo(liveTotal));
      });
    });

    group('stream fault injection', () {
      test('start stream onError is logged and monitor stays running', () async {
        await monitor.start();
        final listenerErrors = <Object>[];
        final sub = monitor.watchTodaySteps(replayLatest: false).listen(
          (_) {},
          onError: listenerErrors.add,
        );

        events.addError(
          StateError('pedometer fault'),
          StackTrace.empty,
        );
        await pumpEventQueue();

        expect(monitor.isRunning, isTrue);
        expect(listenerErrors, isEmpty);
        await sub.cancel();
      });

      test('peekPhoneStepEvent returns null when peek stream errors', () async {
        final peekMonitor = LiveStepMonitor(
          stepAggregation: stepAggregation,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () => Stream<PhoneStepEvent>.error(
            StateError('peek fault'),
          ),
          emitThrottle: Duration.zero,
        );

        expect(peekMonitor.isRunning, isFalse);
        final result = await peekMonitor.peekPhoneStepEvent(
          timeout: const Duration(seconds: 2),
        );
        expect(result, isNull);
        expect(peekMonitor.isRunning, isFalse);
        await peekMonitor.dispose();
      });

      test('peekPhoneStepEvent returns null on timeout when stream is silent', () async {
        final peekMonitor = LiveStepMonitor(
          stepAggregation: stepAggregation,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
          emitThrottle: Duration.zero,
        );

        final stopwatch = Stopwatch()..start();
        final result = await peekMonitor.peekPhoneStepEvent(
          timeout: const Duration(milliseconds: 50),
        );
        stopwatch.stop();

        expect(result, isNull);
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
        await peekMonitor.dispose();
      });
    });

    group('dispose sequencing (AC: #1, #2, #3, #4)', () {
      test('dispose blocks subsequent start — isRunning stays false', () async {
        await monitor.start();
        expect(monitor.isRunning, isTrue);

        await monitor.dispose();
        await monitor.start();

        expect(monitor.isRunning, isFalse);
      });

      test('dispose is idempotent — second call does not throw', () async {
        await monitor.start();
        await monitor.dispose();
        await expectLater(monitor.dispose(), completes);
      });

      test('peekPhoneStepEvent returns null after dispose', () async {
        await monitor.dispose();
        final result = await monitor.peekPhoneStepEvent(
          timeout: const Duration(milliseconds: 50),
        );
        expect(result, isNull);
      });

      test('dispose cancels in-flight peekPhoneStepEvent', () async {
        final peekEvents = StreamController<PhoneStepEvent>();
        final peekMonitor = LiveStepMonitor(
          stepAggregation: stepAggregation,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () => peekEvents.stream,
          emitThrottle: Duration.zero,
        );

        final peekFuture = peekMonitor.peekPhoneStepEvent(
          timeout: const Duration(seconds: 30),
        );
        await pumpEventQueue();
        expect(peekEvents.hasListener, isTrue);

        await peekMonitor.dispose();

        expect(await peekFuture, isNull);
        expect(peekEvents.hasListener, isFalse);
        await peekEvents.close();
      });

      test('hardware subscription cancelled before stepsController closes', () async {
        final teardownOrder = <String>[];
        var streamErrors = <Object>[];

        final trackingMonitor = LiveStepMonitor(
          stepAggregation: stepAggregation,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () {
            final ctrl = StreamController<PhoneStepEvent>(
              onCancel: () => teardownOrder.add('cancel'),
            );
            return ctrl.stream;
          },
          emitThrottle: Duration.zero,
        );

        final sub = trackingMonitor.watchTodaySteps(replayLatest: false).listen(
          (_) {},
          onError: streamErrors.add,
        );

        await trackingMonitor.start();

        await trackingMonitor.dispose();
        teardownOrder.add('close');

        expect(teardownOrder, ['cancel', 'close']);
        expect(streamErrors, isEmpty);
        await sub.cancel();
      });
    });
  });
}
