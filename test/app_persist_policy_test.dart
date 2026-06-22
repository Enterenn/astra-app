import 'dart:async';

import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'core/time/fake_time_provider.dart';
import 'helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';

Future<void> _persistBufferedSteps(
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

  group('shouldTriggerStalenessPersist', () {
    final now = DateTime.utc(2026, 6, 5, 12);
    const cap = Duration(minutes: 5);

    test('returns true when no prior persist', () {
      expect(
        shouldTriggerStalenessPersist(
          lastPersistAt: null,
          now: now,
          maxStaleness: cap,
        ),
        isTrue,
      );
    });

    test('returns false when last persist is within cap', () {
      expect(
        shouldTriggerStalenessPersist(
          lastPersistAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
          now: now,
          maxStaleness: cap,
        ),
        isFalse,
      );
    });

    test('returns true when last persist is at or beyond cap', () {
      expect(
        shouldTriggerStalenessPersist(
          lastPersistAt: now.subtract(const Duration(minutes: 5)),
          now: now,
          maxStaleness: cap,
        ),
        isTrue,
      );
    });
  });

  group('shouldRunResumePhoneCatchUp', () {
    const minPause = Duration(seconds: 10);

    test('returns false when pause is shorter than minPauseForPhoneCatchUp', () {
      expect(
        shouldRunResumePhoneCatchUp(
          persistedNewSteps: false,
          upsertedFromDrain: 0,
          monitorAheadOfDb: false,
          pauseDuration: const Duration(seconds: 9),
          minPauseForPhoneCatchUp: minPause,
        ),
        isFalse,
      );
    });

    test('returns true when pause meets threshold and no drain progress', () {
      expect(
        shouldRunResumePhoneCatchUp(
          persistedNewSteps: false,
          upsertedFromDrain: 0,
          monitorAheadOfDb: false,
          pauseDuration: minPause,
          minPauseForPhoneCatchUp: minPause,
        ),
        isTrue,
      );
    });

    test('returns false when SQLite already advanced on resume drain', () {
      expect(
        shouldRunResumePhoneCatchUp(
          persistedNewSteps: true,
          upsertedFromDrain: 1,
          monitorAheadOfDb: false,
          pauseDuration: minPause,
          minPauseForPhoneCatchUp: minPause,
        ),
        isFalse,
      );
    });

    test('returns false when monitor is ahead of SQLite', () {
      expect(
        shouldRunResumePhoneCatchUp(
          persistedNewSteps: false,
          upsertedFromDrain: 0,
          monitorAheadOfDb: true,
          pauseDuration: minPause,
          minPauseForPhoneCatchUp: minPause,
        ),
        isFalse,
      );
    });
  });

  group('shouldRunResumePhonePeek', () {
    test('returns false when pocket catch-up gate is closed', () {
      expect(
        shouldRunResumePhonePeek(
          likelyPocketWalk: false,
          stepsBeforeResumeCollect: 120,
          stepsAtBackground: 50,
        ),
        isFalse,
      );
    });

    test('returns false when background collection already advanced SQLite', () {
      expect(
        shouldRunResumePhonePeek(
          likelyPocketWalk: true,
          stepsBeforeResumeCollect: 120,
          stepsAtBackground: 50,
        ),
        isFalse,
      );
    });

    test('returns true when long pause left SQLite unchanged at resume', () {
      expect(
        shouldRunResumePhonePeek(
          likelyPocketWalk: true,
          stepsBeforeResumeCollect: 50,
          stepsAtBackground: 50,
        ),
        isTrue,
      );
    });

    test('returns true when background baseline is unknown', () {
      expect(
        shouldRunResumePhonePeek(
          likelyPocketWalk: true,
          stepsBeforeResumeCollect: 50,
          stepsAtBackground: null,
        ),
        isTrue,
      );
    });
  });

  group('staleness fallback during continuous walking', () {
    late Database db;
    late StepIngestionRepository stepIngestion;
    late StepAggregationRepository stepAggregation;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;
    late BackgroundCollector collector;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepIngestion = StepIngestionRepository(db);
      stepAggregation = StepAggregationRepository(db, clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
        activityIdleFlushDelay: const Duration(milliseconds: 500),
      );
      collector = BackgroundCollector(
        sources: [MonitorDrainSource(monitor)],
        normalizer: StepNormalizer(clock: clock),
        repository: stepIngestion,
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await events.close();
      await db.close();
    });

    test(
      'persists via staleness when readings never gap long enough for idle',
      () async {
        const stalenessCap = Duration(milliseconds: 150);
        var lastPersistAt = DateTime.now().subtract(stalenessCap);
        var idleCount = 0;
        final persistDone = Completer<void>();

        monitor.onActivityIdle = () => idleCount++;

        await monitor.start();
        events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(monitor.currentTodaySteps, 0);
        expect(await stepAggregation.getTodaySteps(), 0);

        final stalenessTimer = Timer.periodic(stalenessCap, (_) {
          if (!shouldTriggerStalenessPersist(
            lastPersistAt: lastPersistAt,
            now: DateTime.now(),
            maxStaleness: stalenessCap,
          )) {
            return;
          }
          unawaited(() async {
            await _persistBufferedSteps(monitor, collector);
            lastPersistAt = DateTime.now();
            if (!persistDone.isCompleted) {
              persistDone.complete();
            }
          }());
        });

        try {
          for (var i = 1; i <= 8; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            events.add(
              PhoneStepEvent(
                steps: 100 + i * 10,
                timeStamp: DateTime.utc(2026, 6, 2, 12, i),
              ),
            );
          }

          await persistDone.future.timeout(const Duration(seconds: 2));
        } finally {
          stalenessTimer.cancel();
        }

        expect(idleCount, 0);
        final persisted = await stepAggregation.getTodaySteps();
        expect(persisted, greaterThan(0));
        expect(monitor.currentTodaySteps, greaterThanOrEqualTo(persisted));
      },
    );
  });
}
