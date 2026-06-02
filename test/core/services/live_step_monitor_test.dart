import 'dart:async';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
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

  group('LiveStepMonitor', () {
    late Database db;
    late StepRepository repository;
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
      repository = StepRepository(db: db, clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepRepository: repository,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
    });

    tearDown(() async {
      await monitor.stop();
      monitor.dispose();
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
        repository: repository,
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

      expect(await repository.getTodaySteps(), 20);
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
        stepRepository: repository,
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
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );

      await countingMonitor.beginReconcile();
      await collector.collectOnce(maxReadingsPerSource: 250);
      await countingMonitor.reconcileFromDatabase();
      countingMonitor.endReconcile();

      expect(streamListenCount, 1);
      await countingMonitor.stop();
      countingMonitor.dispose();
    });
  });
}
