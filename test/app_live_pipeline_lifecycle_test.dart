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
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'core/time/fake_time_provider.dart';
import 'helpers/recording_health_fgs.dart';
import 'helpers/sqflite_test_helper.dart';

class _StopCountingMonitor extends LiveStepMonitor {
  _StopCountingMonitor({
    required super.stepRepository,
    required super.baselineRepository,
    required super.clock,
    super.stepEventStreamFactory,
    super.emitThrottle,
  });

  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

class _TestPhoneStreams {
  _TestPhoneStreams()
    : events = StreamController<PhoneStepEvent>.broadcast();

  final StreamController<PhoneStepEvent> events;
  final List<PhoneStepEvent> replayOnSubscribe = [];

  PhoneStepEventStreamFactory get factory => () async* {
    for (final event in replayOnSubscribe) {
      yield event;
    }
    yield* events.stream;
  };
}

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

void _finishResumeCatchUp(TodayCubit cubit) {
  if (cubit.state.foregroundCatchUp) {
    cubit.clearForegroundCatchUp();
  }
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

/// [AstraApp] resume handlers are enqueued via [unawaited] — drain them before
/// unmount/DB close so refreshMetadata / history refresh do not hit a closed DB.
Future<void> _waitForResumePipelineComplete(
  WidgetTester tester,
  TodayCubit cubit,
  LiveStepMonitor monitor, {
  int attempts = 250,
}) async {
  var settledAfterCatchUp = 0;
  for (var attempt = 0; attempt < attempts; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    if (monitor.isRunning &&
        !cubit.state.foregroundCatchUp &&
        cubit.state.status != TodayStatus.loading) {
      settledAfterCatchUp++;
      if (settledAfterCatchUp >= 15) {
        return;
      }
    } else {
      settledAfterCatchUp = 0;
    }
  }
}

Future<void> _unmountAstraApp(WidgetTester tester) async {
  if (tester.any(find.byType(AstraApp))) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraApp live pipeline lifecycle', () {
    late Database db;
    late AppDependencies deps;
    late _TestPhoneStreams phoneStreams;
    late LiveStepMonitor monitor;
    late FakeTimeProvider clock;
    setUp(() async {
      GoalRing.disableStepPersistence = true;
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      final userPreferences = UserPreferencesRepository(db, clock: clock);
      await userPreferences.setOnboardingComplete(true);
      phoneStreams = _TestPhoneStreams();
      monitor = LiveStepMonitor(
        stepRepository: StepRepository(db: db, clock: clock),
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: phoneStreams.factory,
        emitThrottle: Duration.zero,
      );
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
        liveStepMonitor: monitor,
        healthForegroundCoordinator: RecordingHealthFgs(calls: []),
        ingestionSources: [
          MonitorDrainSource(
            monitor,
            phoneFallback: PhonePedometerSource(
              stepEventStreamFactory: phoneStreams.factory,
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      GoalRing.disableStepPersistence = false;
      // Resume pipeline handlers are enqueued via unawaited — brief drain before DB close.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await phoneStreams.events.close();
      await db.close();
    });

    testWidgets('resume ingests pocket-walk buffer while monitor stays alive', (
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 50) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 50) {
            break;
          }
        }
        expect(monitor.isRunning, isTrue);

        phoneStreams.events.add(
          PhoneStepEvent(steps: 250, timeStamp: DateTime.utc(2026, 6, 2, 8, 4)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 300, timeStamp: DateTime.utc(2026, 6, 2, 8, 5)),
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (monitor.currentTodaySteps > 50) {
            break;
          }
        }

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.foregroundCatchUp &&
              (todayCubit!.state.catchUpTargetSteps ?? 0) > 50) {
            break;
          }
        }
        _finishResumeCatchUp(todayCubit!);

        expect(todayCubit!.state.steps, greaterThan(50));
        expect(monitor.isRunning, isTrue);
      });
      await _unmountAstraApp(tester);
    });

    testWidgets('resume catch-up then continues live increments', (tester) async {
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 50) {
            break;
          }
        }
        final stepsBeforePause = todayCubit!.state.steps;
        expect(stepsBeforePause, greaterThanOrEqualTo(50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 50) {
            break;
          }
        }

        phoneStreams.events.add(
          PhoneStepEvent(steps: 250, timeStamp: DateTime.utc(2026, 6, 2, 8, 4)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 300, timeStamp: DateTime.utc(2026, 6, 2, 8, 5)),
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 300; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps > stepsBeforePause) {
            break;
          }
          if (todayCubit!.state.foregroundCatchUp &&
              (todayCubit!.state.catchUpTargetSteps ?? 0) >
                  stepsBeforePause) {
            break;
          }
        }
        if (todayCubit!.state.foregroundCatchUp) {
          _finishResumeCatchUp(todayCubit!);
        }
        final stepsAfterCatchUp = todayCubit!.state.steps;
        expect(stepsAfterCatchUp, greaterThan(stepsBeforePause));

        phoneStreams.events.add(
          PhoneStepEvent(steps: 400, timeStamp: DateTime.utc(2026, 6, 2, 8, 7)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 480, timeStamp: DateTime.utc(2026, 6, 2, 8, 8)),
        );

        var stepsAfterLive = stepsAfterCatchUp;
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          stepsAfterLive = todayCubit!.state.steps;
          if (stepsAfterLive > stepsAfterCatchUp) {
            break;
          }
        }
        expect(stepsAfterLive, greaterThan(stepsAfterCatchUp));
        expect(monitor.isRunning, isTrue);
      });
      await _unmountAstraApp(tester);
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );

        var stepsBeforeResume = 0;
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          stepsBeforeResume = todayCubit!.state.steps;
          if (stepsBeforeResume >= 50) {
            break;
          }
        }
        expect(stepsBeforeResume, greaterThanOrEqualTo(50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 50) {
            break;
          }
        }
        expect(await deps.stepRepository.getTodaySteps(), 50);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 50 &&
              todayCubit!.state.status != TodayStatus.loading) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(50));
        _finishResumeCatchUp(todayCubit!);

        phoneStreams.events.add(
          PhoneStepEvent(steps: 300, timeStamp: DateTime.utc(2026, 6, 2, 8, 7)),
        );
        phoneStreams.events.add(
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
      await _unmountAstraApp(tester);
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 500, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 600, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final liveSteps = monitor.currentTodaySteps;
        expect(liveSteps, 100);

        await Future<void>.delayed(const Duration(milliseconds: 100));
        final displayed = await _waitForStableTodaySteps(todayCubit!);
        expect(displayed, greaterThanOrEqualTo(liveSteps));
      });
      await _unmountAstraApp(tester);
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
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
      await _unmountAstraApp(tester);
    });

    testWidgets('rapid pause resume keeps live subscription alive', (
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );

        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 50) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _waitForResumePipelineComplete(tester, todayCubit!, monitor);
        expect(monitor.isRunning, isTrue);
        _finishResumeCatchUp(todayCubit!);

        phoneStreams.events.add(
          PhoneStepEvent(steps: 300, timeStamp: DateTime.utc(2026, 6, 2, 8, 7)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 380, timeStamp: DateTime.utc(2026, 6, 2, 8, 8)),
        );

        var stepsAfterResume = todayCubit!.state.steps;
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          stepsAfterResume = todayCubit!.state.steps;
          if (stepsAfterResume > 50) {
            break;
          }
        }
        expect(stepsAfterResume, greaterThan(50));
      });
      await _unmountAstraApp(tester);
    });

    testWidgets(
      'resume skips phone peek when background already persisted steps',
      (tester) async {
        TodayCubit? todayCubit;
        late _StopCountingMonitor countingMonitor;

        await tester.runAsync(() async {
          countingMonitor = _StopCountingMonitor(
            stepRepository: StepRepository(db: db, clock: deps.timeProvider),
            baselineRepository: IngestionBaselineRepository(db),
            clock: deps.timeProvider,
            stepEventStreamFactory: phoneStreams.factory,
            emitThrottle: Duration.zero,
          );
          final countingDeps = await AppDependencies.test(
            db: db,
            userPreferences: deps.userPreferences,
            timeProvider: deps.timeProvider,
            liveStepMonitor: countingMonitor,
            healthForegroundCoordinator: RecordingHealthFgs(calls: []),
            ingestionSources: [
              MonitorDrainSource(
                countingMonitor,
                phoneFallback: PhonePedometerSource(
                  stepEventStreamFactory: phoneStreams.factory,
                ),
              ),
            ],
          );

          await tester.pumpWidget(
            AstraApp(
              deps: countingDeps,
              createTodayCubit: (dependencies) {
                todayCubit = _testTodayCubit(dependencies);
                return todayCubit!;
              },
              createHistoryCubit: _testHistoryCubit,
              enablePeriodicPersist: false,
              enableLiveStepPipeline: true,
              minPauseForPhoneCatchUp: const Duration(milliseconds: 10),
            ),
          );
          await tester.pump();
          await _waitForLivePipeline(countingMonitor, todayCubit!);

          phoneStreams.events.add(
            PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
          );
          phoneStreams.events.add(
            PhoneStepEvent(
              steps: 150,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          );
          for (var attempt = 0; attempt < 200; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (todayCubit!.state.steps >= 50) {
              break;
            }
          }
          expect(todayCubit!.state.steps, greaterThanOrEqualTo(50));

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          for (var attempt = 0; attempt < 150; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (await countingDeps.stepRepository.getTodaySteps() >= 50) {
              break;
            }
          }

          phoneStreams.events.add(
            PhoneStepEvent(
              steps: 250,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 4),
            ),
          );
          phoneStreams.events.add(
            PhoneStepEvent(
              steps: 300,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 5),
            ),
          );
          await countingDeps.backgroundCollector.collectOnce();
          final stepsAfterBackgroundCollect =
              await countingDeps.stepRepository.getTodaySteps();
          expect(stepsAfterBackgroundCollect, greaterThan(50));

          await Future<void>.delayed(const Duration(milliseconds: 15));

          final stopCallsBeforeResume = countingMonitor.stopCalls;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          for (var attempt = 0; attempt < 200; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 20));
            if (todayCubit!.state.steps >= stepsAfterBackgroundCollect) {
              break;
            }
          }
          _finishResumeCatchUp(todayCubit!);

          expect(countingMonitor.stopCalls, stopCallsBeforeResume);
          expect(
            todayCubit!.state.steps,
            greaterThanOrEqualTo(stepsAfterBackgroundCollect),
          );
          expect(countingMonitor.isRunning, isTrue);

          phoneStreams.events.add(
            PhoneStepEvent(
              steps: 380,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 8),
            ),
          );
          var stepsAfterLive = todayCubit!.state.steps;
          for (var attempt = 0; attempt < 100; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            stepsAfterLive = todayCubit!.state.steps;
            if (stepsAfterLive > stepsAfterBackgroundCollect) {
              break;
            }
          }
          expect(stepsAfterLive, greaterThan(stepsAfterBackgroundCollect));
        });
        await _unmountAstraApp(tester);
      },
    );

    testWidgets('resume phone catch-up when pocket buffer was empty', (
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
            minPauseForPhoneCatchUp: Duration.zero,
          ),
        );
        await tester.pump();

        await _waitForLivePipeline(monitor, todayCubit!);

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 150, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 50) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 50) {
            break;
          }
        }
        expect(monitor.isRunning, isTrue);

        phoneStreams.replayOnSubscribe
          ..clear()
          ..add(
            PhoneStepEvent(
              steps: 300,
              timeStamp: DateTime.utc(2026, 6, 2, 8, 5),
            ),
          );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 300; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps > 50) {
            break;
          }
          if (todayCubit!.state.foregroundCatchUp &&
              (todayCubit!.state.catchUpTargetSteps ?? 0) > 50) {
            break;
          }
        }
        _finishResumeCatchUp(todayCubit!);

        expect(todayCubit!.state.steps, greaterThan(50));
        expect(monitor.isRunning, isTrue);
      });
      await _unmountAstraApp(tester);
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
        );
        phoneStreams.events.add(
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
      await _unmountAstraApp(tester);
    });

    testWidgets('resume after local midnight shows new day and live works', (
      tester,
    ) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        clock.setNowUtc(DateTime.utc(2026, 6, 7, 20));
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 19)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 7, 20)),
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 100) {
            break;
          }
        }
        expect(todayCubit!.state.steps, 100);
        expect(monitor.trackedLocalDay, '2026-06-07');

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 100) {
            break;
          }
        }

        clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 9));
        phoneStreams.events.add(
          PhoneStepEvent(steps: 220, timeStamp: DateTime.utc(2026, 6, 7, 22, 0)),
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (monitor.trackedLocalDay == '2026-06-08' &&
              todayCubit!.state.steps < 100) {
            break;
          }
        }

        expect(monitor.trackedLocalDay, '2026-06-08');
        expect(todayCubit!.state.steps, lessThan(100));
        expect(todayCubit!.state.foregroundCatchUp, isFalse);
        expect(todayCubit!.state.showCelebration, isFalse);

        phoneStreams.events.add(
          PhoneStepEvent(steps: 240, timeStamp: DateTime.utc(2026, 6, 7, 22, 10)),
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 20) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(20));
        expect(monitor.isRunning, isTrue);
        await _waitForResumePipelineComplete(tester, todayCubit!, monitor);
      });
      await _unmountAstraApp(tester);
    });

    testWidgets('boundary runs after reconcile advanced trackedLocalDay', (
      tester,
    ) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        clock.setNowUtc(DateTime.utc(2026, 6, 7, 20));
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 19)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 7, 20)),
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 100) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(100));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 100) {
            break;
          }
        }

        clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 5));
        await monitor.reconcileFromDatabase();
        expect(monitor.trackedLocalDay, '2026-06-08');
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(100));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _waitForResumePipelineComplete(tester, todayCubit!, monitor);
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps < 100) {
            break;
          }
        }

        expect(monitor.trackedLocalDay, '2026-06-08');
        expect(todayCubit!.state.steps, lessThan(100));
        expect(todayCubit!.state.foregroundCatchUp, isFalse);
      });
      await _unmountAstraApp(tester);
    });

    testWidgets('goal met yesterday does not replay celebration on new day', (
      tester,
    ) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        await deps.userPreferences.setDailyStepGoal(100);
        clock.setNowUtc(DateTime.utc(2026, 6, 7, 20));
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

        phoneStreams.events.add(
          PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 7, 19)),
        );
        phoneStreams.events.add(
          PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 7, 20)),
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (todayCubit!.state.steps >= 100 &&
              todayCubit!.state.showCelebration) {
            break;
          }
        }
        expect(todayCubit!.state.steps, greaterThanOrEqualTo(100));
        expect(todayCubit!.state.showCelebration, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        for (var attempt = 0; attempt < 150; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (await deps.stepRepository.getTodaySteps() >= 100) {
            break;
          }
        }

        clock.setNowUtc(DateTime.utc(2026, 6, 7, 22, 9));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var attempt = 0; attempt < 200; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (monitor.trackedLocalDay == '2026-06-08' &&
              !todayCubit!.state.showCelebration) {
            break;
          }
        }

        expect(monitor.trackedLocalDay, '2026-06-08');
        expect(todayCubit!.state.showCelebration, isFalse);
        expect(todayCubit!.state.steps, lessThan(100));
      });
      await _unmountAstraApp(tester);
    });
  });

  // AdpBleSource can block foreground backfill when SQLite is pre-seeded; use monitor-only ingest.
  group('cold start with SQLite baseline', () {
    late Database db;
    late AppDependencies deps;
    late _TestPhoneStreams phoneStreams;
    late LiveStepMonitor monitor;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      final userPreferences = UserPreferencesRepository(db, clock: clock);
      await userPreferences.setOnboardingComplete(true);
      phoneStreams = _TestPhoneStreams();
      monitor = LiveStepMonitor(
        stepRepository: StepRepository(db: db, clock: clock),
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: phoneStreams.factory,
        emitThrottle: Duration.zero,
      );
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
        liveStepMonitor: monitor,
        healthForegroundCoordinator: RecordingHealthFgs(calls: []),
        ingestionSources: [
          MonitorDrainSource(
            monitor,
            phoneFallback: PhonePedometerSource(
              stepEventStreamFactory: phoneStreams.factory,
            ),
          ),
        ],
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
      await phoneStreams.events.close();
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

          phoneStreams.events.add(
            PhoneStepEvent(steps: 1000, timeStamp: DateTime.utc(2026, 6, 2, 8)),
          );
          phoneStreams.events.add(
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
        await _unmountAstraApp(tester);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
