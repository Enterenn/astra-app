import 'dart:async';

import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'core/time/fake_time_provider.dart';
import 'helpers/recording_health_fgs.dart';
import 'helpers/sqflite_test_helper.dart';

TodayCubit _testTodayCubit(AppDependencies deps) {
  return TodayCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
    clock: deps.timeProvider,
    activityPermissionGranted: () async => true,
  );
}

HistoryCubit _testHistoryCubit(AppDependencies deps) {
  return HistoryCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
  );
}

Future<int> _waitForStableTodaySteps(
  TodayCubit cubit, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (cubit.state.status != TodayStatus.loading) {
      return cubit.state.steps;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return cubit.state.steps;
}

Future<void> _waitForLivePipeline(
  LiveStepMonitor monitor,
  TodayCubit cubit, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (monitor.isRunning && cubit.state.status != TodayStatus.loading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraApp live pipeline lifecycle', () {
    late Database db;
    late AppDependencies deps;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepRepository: StepRepository(db: db, clock: clock),
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
        liveStepMonitor: monitor,
        healthForegroundCoordinator: RecordingHealthFgs(calls: []),
      );
    });

    tearDown(() async {
      await events.close();
      await db.close();
    });

    testWidgets('resume syncs live steps after background walk', (tester) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              todayCubit = _testTodayCubit(dependencies);
              return todayCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
          ),
        );
        await tester.pump();

        await _waitForLivePipeline(monitor, todayCubit!);

        events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );

        var stepsBeforeResume = 0;
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          stepsBeforeResume = todayCubit!.state.steps;
          if (stepsBeforeResume >= 50) {
            break;
          }
        }
        expect(stepsBeforeResume, 50);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await _waitForStableTodaySteps(todayCubit!), 50);

        events.add(
          PhoneStepEvent(steps: 300, timeStamp: DateTime.utc(2026, 6, 2, 8, 7)),
        );
        events.add(
          PhoneStepEvent(steps: 380, timeStamp: DateTime.utc(2026, 6, 2, 8, 8)),
        );

        var stepsAfterResume = stepsBeforeResume;
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          stepsAfterResume = todayCubit!.state.steps;
          if (stepsAfterResume > stepsBeforeResume) {
            break;
          }
        }
        expect(stepsAfterResume, greaterThan(stepsBeforeResume));
      });
    });

    testWidgets('cold start does not drop steps below live monitor total', (
      tester,
    ) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              todayCubit = _testTodayCubit(dependencies);
              return todayCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
          ),
        );
        await tester.pump();

        await _waitForLivePipeline(monitor, todayCubit!);

        events.add(
          PhoneStepEvent(steps: 500, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        events.add(
          PhoneStepEvent(steps: 600, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final liveSteps = monitor.currentTodaySteps;
        expect(liveSteps, 100);

        await Future<void>.delayed(const Duration(milliseconds: 100));
        final displayed = await _waitForStableTodaySteps(todayCubit!);
        expect(displayed, greaterThanOrEqualTo(liveSteps));
      });
    });

    testWidgets('persists live monitor buffer when app pauses', (tester) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              todayCubit = _testTodayCubit(dependencies);
              return todayCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
          ),
        );
        await tester.pump();
        await _waitForLivePipeline(monitor, todayCubit!);

        events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        events.add(
          PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (monitor.currentTodaySteps >= 100) {
            break;
          }
        }
        expect(monitor.currentTodaySteps, 100);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 100) {
            break;
          }
        }
        expect(await deps.stepRepository.getTodaySteps(), 100);
      });
    });

    testWidgets('reattach preserves monitor total when cubit is recreated', (
      tester,
    ) async {
      TodayCubit? firstCubit;
      TodayCubit? secondCubit;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              if (firstCubit == null) {
                firstCubit = _testTodayCubit(dependencies);
                return firstCubit!;
              }
              secondCubit = _testTodayCubit(dependencies);
              return secondCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
          ),
        );
        await tester.pump();
        await _waitForLivePipeline(monitor, firstCubit!);

        events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        events.add(
          PhoneStepEvent(steps: 250, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );

        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (firstCubit!.state.steps >= 150) {
            break;
          }
        }
        expect(firstCubit!.state.steps, 150);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              secondCubit = _testTodayCubit(dependencies);
              return secondCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
          ),
        );
        await tester.pump();
        await _waitForLivePipeline(monitor, secondCubit!);

        expect(secondCubit!.state.steps, greaterThanOrEqualTo(150));
      });
    });
  });

  // AdpBleSource can block foreground backfill when SQLite is pre-seeded; use monitor-only ingest.
  group('cold start with SQLite baseline', () {
    late Database db;
    late AppDependencies deps;
    late StreamController<PhoneStepEvent> events;
    late LiveStepMonitor monitor;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      events = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepRepository: StepRepository(db: db, clock: clock),
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
        liveStepMonitor: monitor,
        healthForegroundCoordinator: RecordingHealthFgs(calls: []),
        ingestionSources: [MonitorDrainSource(monitor)],
      );
      await deps.stepRepository.upsertIngestionBucket(
        NormalizedStepBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 6),
          endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
          value: 800,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      );
    });

    tearDown(() async {
      await events.close();
      await db.close();
    });

    testWidgets(
      'cold start shows live total when DB sum is lower (COLD_START_RACE)',
      (tester) async {
        TodayCubit? todayCubit;

        await tester.runAsync(() async {
          await tester.pumpWidget(
            AstraApp(
              deps: deps,
              createTodayCubit: (dependencies) {
                todayCubit = _testTodayCubit(dependencies);
                return todayCubit!;
              },
              createHistoryCubit: _testHistoryCubit,
              enablePeriodicPersist: false,
              enableLiveStepPipeline: true,
            ),
          );
          await tester.pump();

          await _waitForLivePipeline(monitor, todayCubit!);

          // AstraApp bind: refresh(silent) → attach → syncSteps (no manual refresh).
          expect(todayCubit!.state.steps, greaterThanOrEqualTo(800));

          events.add(
            PhoneStepEvent(steps: 1000, timeStamp: DateTime.utc(2026, 6, 2, 8)),
          );
          events.add(
            PhoneStepEvent(
              steps: 1250,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          );

          for (var attempt = 0; attempt < 50; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (monitor.currentTodaySteps >= 1050 &&
                todayCubit!.state.steps >= 1050) {
              break;
            }
          }

          expect(monitor.currentTodaySteps, greaterThanOrEqualTo(1050));
          expect(todayCubit!.state.steps, greaterThanOrEqualTo(1050));
        });
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
