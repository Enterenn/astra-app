import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/step_reading.dart';
import '../../../presentation/cubits/today_state.dart';
import '../../debug/live_pipeline_log.dart';
import '../../di/app_dependencies.dart';
import 'lifecycle_policy.dart'
    show
        kResumePhoneCatchUpTimeout,
        shouldRunResumePhoneCatchUp,
        shouldRunResumePhonePeek;
import 'lifecycle_session_state.dart';

/// Cold start, bind, resume, reattach, backfill reconcile (Story 25-2).
class LifecycleLivePipelineService {
  LifecycleLivePipelineService({
    required this.depsGetter,
    required this.session,
  });

  final AppDependencies Function() depsGetter;
  final LifecycleSessionState session;

  AppDependencies get deps => depsGetter();

  /// Wired by façade after sibling services are constructed.
  late Future<void> Function() runLocalDayBoundaryIfNeeded;
  late Future<int> Function({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) enqueuePersistCycleReturningCount;
  late void Function() wireLiveMonitorDayBoundaryCallbacks;
  late void Function() startActivityBasedPersist;
  late void Function() scheduleMidnightBoundaryTimer;

  /// Foreground resume: keep the pedometer subscription alive, drain pocket
  /// buffer, then one-shot phone catch-up only when SQLite did not advance.
  Future<void> resumeLivePipeline() async {
    try {
      await runLocalDayBoundaryIfNeeded();
      final monitor = deps.liveStepMonitor;
      final repo = deps.stepAggregation;
      final stepsBeforeCollect = await repo.getTodaySteps();

      final upsertedFromDrain = await enqueuePersistCycleReturningCount(
        enableGoalNotification: false,
      );

      final stepsAfterDrain = await repo.getTodaySteps();
      final persistedNewSteps = stepsAfterDrain > stepsBeforeCollect;
      final monitorAheadOfDb = monitor.currentTodaySteps > stepsAfterDrain;
      final pauseDuration = session.backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(session.backgroundedAt!);
      session.backgroundedAt = null;
      final likelyPocketWalk = shouldRunResumePhoneCatchUp(
        persistedNewSteps: persistedNewSteps,
        upsertedFromDrain: upsertedFromDrain,
        monitorAheadOfDb: monitorAheadOfDb,
        pauseDuration: pauseDuration,
        minPauseForPhoneCatchUp: session.minPauseForPhoneCatchUp,
      );
      final needsPhonePeek = shouldRunResumePhonePeek(
        likelyPocketWalk: likelyPocketWalk,
        stepsBeforeResumeCollect: stepsBeforeCollect,
        stepsAtBackground: session.stepsAtBackground,
      );
      session.stepsAtBackground = null;

      if (needsPhonePeek) {
        final wasRunning = monitor.isRunning;
        if (wasRunning) {
          await monitor.stop();
        }
        final pocketEvent = await monitor.peekPhoneStepEvent(
          timeout: kResumePhoneCatchUpTimeout,
        );
        if (pocketEvent != null) {
          monitor.enqueueReadingForCollection(
            StepReading(
              cumulativeSteps: pocketEvent.steps,
              observedAtUtc: pocketEvent.timeStamp,
            ),
          );
          if (!monitor.isRunning) {
            await monitor.start();
          }
          await enqueuePersistCycleReturningCount(
            enableGoalNotification: false,
          );
        } else if (wasRunning && !monitor.isRunning) {
          await monitor.start();
        }
      }

      if (monitor.isRunning) {
        await monitor.reconcileFromDatabase();
      } else {
        await monitor.start();
        await monitor.reconcileFromDatabase();
      }

      await bindLiveMonitorToToday(foregroundCatchUp: true);
      session.livePipelineStarted = true;
      livePipelineLog(
        'app',
        'resume pipeline DONE',
        details: {
          'pauseSec': pauseDuration.inSeconds,
          'upsertedDrain': upsertedFromDrain,
          'stepsBefore': stepsBeforeCollect,
          'stepsAfterDrain': stepsAfterDrain,
          'phonePeek': needsPhonePeek,
          'monitorRunning': monitor.isRunning,
          'monitorTotal': monitor.currentTodaySteps,
          'cubitSteps': session.todayCubit?.state.steps,
          'catchUp': session.todayCubit?.state.foregroundCatchUp ?? false,
        },
      );
      await session.todayCubit?.refreshMetadata();
      await session.historyCubit?.refresh(silent: true);
      await session.myDataCubit?.refresh(silent: true);
    } catch (error, stackTrace) {
      livePipelineLog(
        'app',
        'resume pipeline ERROR',
        details: {'error': error},
      );
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      session.todayCubit?.setLiveStepAppliesPaused(false);
    }
  }

  Future<void> initialTodayRefresh() async {
    await session.foregroundBackfill;
    logColdStartPhase('cold start backfill DONE');
    if (!session.mounted()) {
      return;
    }
    await session.todayCubit?.refresh();
    logColdStartReadyIfNeeded();
  }

  void logColdStartPhase(
    String phase, {
    Map<String, Object?> details = const {},
  }) {
    final stopwatch = session.coldStartStopwatch;
    if (stopwatch == null) {
      return;
    }
    livePipelineLog(
      'app',
      phase,
      details: {
        'elapsedMs': stopwatch.elapsedMilliseconds,
        ...details,
      },
    );
  }

  void logColdStartReadyIfNeeded() {
    if (session.coldStartReadyLogged || session.coldStartStopwatch == null) {
      return;
    }
    final cubit = session.todayCubit;
    if (cubit == null || cubit.state.status == TodayStatus.loading) {
      return;
    }
    session.coldStartReadyLogged = true;
    session.coldStartStopwatch!.stop();
    logColdStartPhase(
      'cold start UI READY',
      details: {
        'steps': cubit.state.steps,
        'status': cubit.state.status.name,
      },
    );
  }

  /// First launch or hot-reload cubit recreate — never overwrite live total with
  /// a stale SQLite-only [TodayCubit.refresh].
  Future<void> ensureLivePipelineAttached() async {
    if (!session.livePipelineStarted) {
      await startLivePipelineFirstTime();
      return;
    }
    await reattachLivePipeline();
  }

  /// Cold-start live pipeline (permission granted):
  /// fast-path SQLite paint → live attach; backfill runs in parallel.
  ///
  /// See Today Display Truth Model in
  /// `_bmad-output/planning-artifacts/architecture.md`.
  Future<void> startLivePipelineFirstTime() async {
    if (!session.enableLiveStepPipeline) {
      return;
    }
    await session.todayCubit?.refreshFastPath();
    if (!session.mounted()) {
      return;
    }
    await bindLiveMonitorToToday(skipSqliteRefresh: true);
    if (!session.mounted()) {
      return;
    }
    unawaited(reconcileAfterBackfillCompletes());
    session.livePipelineStarted = true;
    logColdStartPhase(
      'cold start pipeline DONE',
      details: {
        'monitorRunning': deps.liveStepMonitor.isRunning,
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': session.todayCubit?.state.steps,
      },
    );
    logColdStartReadyIfNeeded();
    wireLiveMonitorDayBoundaryCallbacks();
    startActivityBasedPersist();
    scheduleMidnightBoundaryTimer();
  }

  /// Non-blocking: after foreground backfill upserts, reconcile monitor + Today
  /// without regressing the fast-path display (Today Display Truth Model).
  Future<void> reconcileAfterBackfillCompletes() async {
    try {
      await session.foregroundBackfill;
      logColdStartPhase('cold start backfill DONE');
      if (!session.mounted()) {
        return;
      }
      final monitor = deps.liveStepMonitor;
      if (monitor.isRunning) {
        await monitor.reconcileFromDatabase();
        await session.todayCubit?.syncSteps(
          monitor.currentTodaySteps,
          clampStaleDisplay: true,
        );
      } else {
        await session.todayCubit?.refresh(silent: true);
      }
    } catch (_) {
      // Backfill failure must not crash; fast-path SQLite remains visible.
    }
  }

  Future<void> reattachLivePipeline() async {
    if (!session.mounted()) {
      return;
    }
    await bindLiveMonitorToToday();
  }

  Future<void> bindLiveMonitorToToday({
    bool foregroundCatchUp = false,
    bool skipSqliteRefresh = false,
  }) async {
    if (!await deps.activityPermissionGranted()) {
      livePipelineLog('app', 'bind SKIPPED reason=no_permission');
      await session.todayCubit?.refresh();
      return;
    }

    final monitor = deps.liveStepMonitor;
    if (!monitor.isRunning) {
      // On cold start (skipSqliteRefresh: true), fast path already read the
      // authoritative SQLite aggregate — seed the monitor to avoid duplicate reads.
      // Resume / foregroundCatchUp paths pass no seed (full DB reads preserved).
      final seedSteps =
          skipSqliteRefresh ? session.todayCubit?.state.steps : null;
      await monitor.start(seedPersistedSteps: seedSteps);
      await monitor.reconcileFromDatabase(seedPersistedSteps: seedSteps);
    }

    // SQLite daily sum before live overlay (Today Display Truth Model).
    if (!foregroundCatchUp && !skipSqliteRefresh) {
      await session.todayCubit?.refresh(silent: true);
    }

    if (foregroundCatchUp) {
      await session.todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        foregroundCatchUp: true,
      );
      // When catch-up was skipped (already aligned), replayLatest re-attaches
      // the stream without triggering a redundant GoalRing count-up animation.
      final catchUpActive = session.todayCubit?.state.foregroundCatchUp ?? false;
      session.todayCubit?.attachLiveMonitor(
        monitor,
        replayLatest: !catchUpActive,
      );
    } else {
      session.todayCubit?.attachLiveMonitor(monitor);
      await session.todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        clampStaleDisplay: true,
      );
    }
    livePipelineLog(
      'app',
      'bindLiveMonitor',
      details: {
        'foregroundCatchUp': foregroundCatchUp,
        'monitorRunning': monitor.isRunning,
        'monitorTotal': monitor.currentTodaySteps,
        'cubitSteps': session.todayCubit?.state.steps,
        'catchUp': session.todayCubit?.state.foregroundCatchUp ?? false,
      },
    );
    // Cold-start fast path already painted SQLite; resume catch-up skips refresh.
    if (foregroundCatchUp) {
      await session.todayCubit?.refreshMetadata();
    } else {
      logColdStartReadyIfNeeded();
    }
  }
}
