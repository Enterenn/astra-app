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

  group('LiveStepMonitor day rollover', () {
    late Database db;
    late StepRepository repository;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;
    late BackgroundCollector collector;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 7, 21, 0),
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
      collector = BackgroundCollector(
        sources: [MonitorDrainSource(monitor)],
        normalizer: StepNormalizer(clock: clock),
        repository: repository,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await monitor.stop();
      monitor.dispose();
      await events.close();
      await db.close();
    });

    test('reconcileFromDatabase does not preserve yesterday floor on new day', () async {
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 20)),
      );
      events.add(
        PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 7, 21)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 50);
      expect(monitor.trackedLocalDay, '2026-06-07');

      clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 9));
      await _persistBufferedSteps(monitor, collector);
      await monitor.reconcileFromDatabase();

      expect(monitor.trackedLocalDay, '2026-06-08');
      expect(monitor.currentTodaySteps, 0);
      expect(monitor.currentTodaySteps, isNot(150));
    });

    test('resetForNewLocalDay reloads SQLite total without phantom pendingDelta', () async {
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 80, timeStamp: DateTime.utc(2026, 6, 7, 20)),
      );
      events.add(
        PhoneStepEvent(steps: 120, timeStamp: DateTime.utc(2026, 6, 7, 21)),
      );
      await Future<void>.delayed(Duration.zero);

      clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 5));
      await _persistBufferedSteps(monitor, collector);
      await monitor.resetForNewLocalDay();

      expect(monitor.trackedLocalDay, '2026-06-08');
      expect(monitor.currentTodaySteps, 0);

      events.add(
        PhoneStepEvent(steps: 125, timeStamp: DateTime.utc(2026, 6, 7, 22, 6)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 5);
    });

    test('defers delta apply on day change when callback unset', () async {
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 20)),
      );
      events.add(
        PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 7, 21)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 50);

      clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 1));
      monitor.onLocalDayBoundary = null;
      events.add(
        PhoneStepEvent(steps: 170, timeStamp: DateTime.utc(2026, 6, 7, 22, 0)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(monitor.trackedLocalDay, '2026-06-07');
      expect(monitor.currentTodaySteps, 50);
    });

    test('resetForNewLocalDay ignores closing-day buffer readings', () async {
      await monitor.start();
      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 20)),
      );
      events.add(
        PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 7, 21)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 50);

      clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 2));
      events.add(
        PhoneStepEvent(steps: 170, timeStamp: DateTime.utc(2026, 6, 7, 22, 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.currentTodaySteps, 50);

      await _persistBufferedSteps(monitor, collector);
      await monitor.resetForNewLocalDay();

      expect(monitor.trackedLocalDay, '2026-06-08');
      expect(monitor.currentTodaySteps, 20);
    });
  });
}
