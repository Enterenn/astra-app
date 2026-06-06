import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/debug/live_pipeline_log.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/live_step_monitor.dart';
import 'data/models/step_reading.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/cubits/history_cubit.dart';
import 'presentation/cubits/my_data_cubit.dart';
import 'presentation/cubits/today_cubit.dart';
import 'presentation/cubits/today_state.dart';
import 'presentation/onboarding/onboarding_flow.dart';
import 'presentation/screens/app_scaffold.dart';

class AstraApp extends StatefulWidget {
  const AstraApp({
    super.key,
    required this.deps,
    this.createOnboardingCubit,
    this.createTodayCubit,
    this.createHistoryCubit,
    this.createMyDataCubit,
    this.enablePeriodicPersist = true,
    this.enableLiveStepPipeline = true,
    this.maxPersistStaleness = kMaxPersistStaleness,
    this.minPauseForPhoneCatchUp = const Duration(seconds: 10),
  });

  final AppDependencies deps;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
  createOnboardingCubit;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
  final HistoryCubit Function(AppDependencies deps)? createHistoryCubit;
  final MyDataCubit Function(AppDependencies deps)? createMyDataCubit;
  final bool enablePeriodicPersist;
  final bool enableLiveStepPipeline;

  /// Override in tests to avoid multi-minute [Timer.periodic] waits.
  final Duration maxPersistStaleness;

  /// Resume phone catch-up runs only after at least this long in background.
  @visibleForTesting
  final Duration minPauseForPhoneCatchUp;

  @override
  State<AstraApp> createState() => _AstraAppState();
}

/// Safety net: persist at least this often during continuous walking.
const kMaxPersistStaleness = Duration(minutes: 5);

/// One-shot phone read after unlock when the live buffer had no pocket events.
const kResumePhoneCatchUpTimeout = Duration(seconds: 8);

/// Whether the staleness fallback should run a persist cycle.
@visibleForTesting
bool shouldTriggerStalenessPersist({
  required DateTime? lastPersistAt,
  required DateTime now,
  required Duration maxStaleness,
}) {
  return lastPersistAt == null ||
      now.difference(lastPersistAt) >= maxStaleness;
}

/// Whether resume should stop the monitor briefly for a one-shot phone peek.
@visibleForTesting
bool shouldRunResumePhoneCatchUp({
  required bool persistedNewSteps,
  required int upsertedFromDrain,
  required bool monitorAheadOfDb,
  required Duration pauseDuration,
  required Duration minPauseForPhoneCatchUp,
}) {
  return !persistedNewSteps &&
      upsertedFromDrain == 0 &&
      !monitorAheadOfDb &&
      pauseDuration >= minPauseForPhoneCatchUp;
}

/// Whether resume should briefly stop the monitor for a one-shot phone peek.
///
/// Skips the destructive stop/peek cycle when background collection (pause
/// persist and/or FGS) already advanced SQLite during the lock — the Fairphone
/// long-walk scenario where peek would aggravate a zombie subscription.
@visibleForTesting
bool shouldRunResumePhonePeek({
  required bool likelyPocketWalk,
  required int stepsBeforeResumeCollect,
  required int? stepsAtBackground,
}) {
  if (!likelyPocketWalk) {
    return false;
  }
  if (stepsAtBackground != null &&
      stepsBeforeResumeCollect > stepsAtBackground) {
    return false;
  }
  return true;
}

class _AstraAppState extends State<AstraApp> with WidgetsBindingObserver {
  /// Must cover [LiveStepMonitor.maxBufferedReadings] so activity-idle persist
  /// normalizes every buffered phone reading in one collect.
  static const _persistMaxReadingsPerSource = 250;

  late bool _showMainShell;
  TodayCubit? _todayCubit;
  HistoryCubit? _historyCubit;
  MyDataCubit? _myDataCubit;
  late final Future<int> _foregroundBackfill;
  Timer? _stalenessPersistTimer;
  DateTime? _lastPersistAt;
  bool _livePipelineStarted = false;
  DateTime? _backgroundedAt;
  int? _stepsAtBackground;
  Future<void>? _persistInFlight;
  void Function(String message)? _showDebugSnackBar;
  Future<void>? _lifecycleTransitionInFlight;
  Stopwatch? _coldStartStopwatch;
  bool _coldStartReadyLogged = false;

  @override
  void initState() {
    super.initState();
    _showMainShell = widget.deps.initialOnboardingComplete;
    WidgetsBinding.instance.addObserver(this);
    if (_showMainShell) {
      _coldStartStopwatch = Stopwatch()..start();
      livePipelineLog('app', 'cold start START', details: {'elapsedMs': 0});
    }
    _foregroundBackfill = widget.enableLiveStepPipeline
        ? _runPersistCycle(enableGoalNotification: true)
        : widget.deps.backgroundCollector.collectOnce(
            enableGoalNotification: true,
          );
  }

  @override
  void dispose() {
    _stopActivityBasedPersist();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.deps.liveStepMonitor.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_enqueueLifecycleTransition(_onAppBackgrounded));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_enqueueLifecycleTransition(_onAppForegrounded));
    }
  }

  /// Serializes pause/resume handlers so foreground recovery cannot race background persist.
  Future<void> _enqueueLifecycleTransition(
    Future<void> Function() operation,
  ) async {
    while (_lifecycleTransitionInFlight != null) {
      await _lifecycleTransitionInFlight;
    }

    late final Future<void> transition;
    transition = operation();
    _lifecycleTransitionInFlight = transition;
    try {
      await transition;
    } finally {
      if (_lifecycleTransitionInFlight == transition) {
        _lifecycleTransitionInFlight = null;
      }
    }
  }

  Future<void> _onAppBackgrounded() async {
    _backgroundedAt = DateTime.now();
    livePipelineLog(
      'app',
      'lifecycle PAUSED',
      details: {
        'monitorRunning': widget.deps.liveStepMonitor.isRunning,
        'monitorTotal': widget.deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
      },
    );
    await _persistOnPause();
    if (!_showMainShell) {
      return;
    }
    _stepsAtBackground = await widget.deps.stepRepository.getTodaySteps();
    _stopActivityBasedPersist();
    _todayCubit?.setLiveStepAppliesPaused(true);
    final healthFgs = widget.deps.healthForegroundCoordinator;
    await healthFgs.setUiActive(false);
    await healthFgs.startHealthCollectionService();
  }

  Future<void> _onAppForegrounded() async {
    livePipelineLog('app', 'lifecycle RESUMED');
    await widget.deps.databaseSession.ensureOpen();
    final healthFgs = widget.deps.healthForegroundCoordinator;
    await healthFgs.stopHealthCollectionService();
    await healthFgs.setUiActive(true);
    // Heavy DB maintenance (downsample + VACUUM) must not run here — it can
    // invalidate the UI SQLite connection while _resumeLivePipeline reads/writes.
    // Android: WorkManager; manual: My Data purge/optimize flows.
    if (widget.enableLiveStepPipeline && _showMainShell) {
      await _resumeLivePipeline();
    } else {
      await _enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: true,
      );
      await _todayCubit?.refreshMetadata();
      await _historyCubit?.refresh(silent: true);
      await _myDataCubit?.refresh(silent: true);
    }
    if (_livePipelineStarted && widget.enablePeriodicPersist) {
      _startActivityBasedPersist();
    }
  }

  /// Flushes buffered steps to SQLite when the app leaves the foreground.
  ///
  /// Best-effort before a possible process kill — no UI updates (user cannot see
  /// Today). [AppLifecycleState.resumed] still reconciles and syncs the cubit.
  Future<void> _persistOnPause() async {
    if (!_showMainShell) {
      return;
    }
    await _enqueuePersistCycle(enableGoalNotification: false);
  }

  /// Persists buffered phone readings via [BackgroundCollector] (sole bucket writer),
  /// then reconciles [LiveStepMonitor] from SQLite without lowering the overlay.
  Future<int> _runPersistCycle({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    final monitor = widget.deps.liveStepMonitor;
    final collector = widget.deps.backgroundCollector;
    await monitor.beginReconcile();
    try {
      final upserted = await collector.collectOnce(
        maxReadingsPerSource: _persistMaxReadingsPerSource,
        enableGoalNotification: enableGoalNotification,
        sourceTimeout: sourceTimeout,
      );
      await monitor.reconcileFromDatabase();
      _lastPersistAt = DateTime.now();
      return upserted;
    } finally {
      monitor.endReconcile();
    }
  }

  Future<void> _runPersistIfNotInFlight() async {
    if (!_showMainShell || !_livePipelineStarted) {
      return;
    }
    await _enqueuePersistCycle(
      enableGoalNotification: false,
      syncTodayAfter: true,
    );
  }

  /// Activity-idle persist with debug feedback (snackbar + structured log).
  Future<void> _onActivityIdlePersist() async {
    if (!_showMainShell || !_livePipelineStarted) {
      return;
    }

    final monitor = widget.deps.liveStepMonitor;
    final repo = widget.deps.stepRepository;
    final persistedBefore = await repo.getTodaySteps();
    final displayBefore = monitor.currentTodaySteps;

    livePipelineLog(
      'app',
      'idle flush START',
      details: {
        'persistedBefore': persistedBefore,
        'displayBefore': displayBefore,
      },
    );

    await _enqueuePersistCycle(
      enableGoalNotification: false,
      syncTodayAfter: true,
    );

    if (!mounted) {
      return;
    }

    final persistedAfter = await repo.getTodaySteps();
    final total = monitor.currentTodaySteps;
    final pendingDelta = total - persistedAfter;
    final message =
        'Idle flush · persisted $persistedAfter · total $total'
        '${pendingDelta > 0 ? ' · pending $pendingDelta' : ''}';

    livePipelineLog(
      'app',
      'idle flush complete',
      details: {
        'persistedBefore': persistedBefore,
        'persisted': persistedAfter,
        'pendingDelta': pendingDelta,
        'total': total,
        'displayBefore': displayBefore,
      },
    );

    if (kDebugMode) {
      final show = _showDebugSnackBar;
      if (show == null) {
        livePipelineLog(
          'app',
          'idle flush snackbar SKIPPED reason=no_scaffold_host',
        );
        return;
      }
      livePipelineLog('app', 'idle flush snackbar SHOW');
      show(message);
    }
  }

  /// Serializes pause, idle, staleness, and resume persist cycles.
  Future<void> _enqueuePersistCycle({
    required bool enableGoalNotification,
    bool syncTodayAfter = false,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    operation = _persistCycleWithOptionalSync(
      enableGoalNotification: enableGoalNotification,
      syncTodayAfter: syncTodayAfter,
    );
    _persistInFlight = operation;
    try {
      await operation;
    } finally {
      if (_persistInFlight == operation) {
        _persistInFlight = null;
      }
    }
  }

  Future<void> _persistCycleWithOptionalSync({
    required bool enableGoalNotification,
    required bool syncTodayAfter,
  }) async {
    if (widget.enableLiveStepPipeline) {
      if (!_livePipelineStarted && !enableGoalNotification) {
        return;
      }
      await _runPersistCycle(enableGoalNotification: enableGoalNotification);
      if (syncTodayAfter) {
        await _todayCubit?.syncSteps(
          widget.deps.liveStepMonitor.currentTodaySteps,
        );
      }
      return;
    }

    await widget.deps.backgroundCollector.collectOnce(
      enableGoalNotification: enableGoalNotification,
    );
    if (syncTodayAfter) {
      await _todayCubit?.refresh(silent: true);
    }
  }

  /// Foreground resume: keep the pedometer subscription alive, drain pocket
  /// buffer, then one-shot phone catch-up only when SQLite did not advance.
  Future<void> _resumeLivePipeline() async {
    try {
      final monitor = widget.deps.liveStepMonitor;
      final repo = widget.deps.stepRepository;
      final stepsBeforeCollect = await repo.getTodaySteps();

      final upsertedFromDrain = await _enqueuePersistCycleReturningCount(
        enableGoalNotification: false,
      );

      final stepsAfterDrain = await repo.getTodaySteps();
      final persistedNewSteps = stepsAfterDrain > stepsBeforeCollect;
      final monitorAheadOfDb = monitor.currentTodaySteps > stepsAfterDrain;
      final pauseDuration = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      final likelyPocketWalk = shouldRunResumePhoneCatchUp(
        persistedNewSteps: persistedNewSteps,
        upsertedFromDrain: upsertedFromDrain,
        monitorAheadOfDb: monitorAheadOfDb,
        pauseDuration: pauseDuration,
        minPauseForPhoneCatchUp: widget.minPauseForPhoneCatchUp,
      );
      final needsPhonePeek = shouldRunResumePhonePeek(
        likelyPocketWalk: likelyPocketWalk,
        stepsBeforeResumeCollect: stepsBeforeCollect,
        stepsAtBackground: _stepsAtBackground,
      );
      _stepsAtBackground = null;

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
          await _enqueuePersistCycleReturningCount(
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

      await _bindLiveMonitorToToday(foregroundCatchUp: true);
      _livePipelineStarted = true;
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
          'cubitSteps': _todayCubit?.state.steps,
          'catchUp': _todayCubit?.state.foregroundCatchUp ?? false,
        },
      );
      await _todayCubit?.refreshMetadata();
      await _historyCubit?.refresh(silent: true);
      await _myDataCubit?.refresh(silent: true);
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
      _todayCubit?.setLiveStepAppliesPaused(false);
    }
  }

  Future<int> _enqueuePersistCycleReturningCount({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    var upserted = 0;
    operation = () async {
      if (widget.enableLiveStepPipeline) {
        if (!_livePipelineStarted && !enableGoalNotification) {
          return;
        }
        upserted = await _runPersistCycle(
          enableGoalNotification: enableGoalNotification,
          sourceTimeout: sourceTimeout,
        );
        return;
      }
      upserted = await widget.deps.backgroundCollector.collectOnce(
        enableGoalNotification: enableGoalNotification,
        sourceTimeout: sourceTimeout,
      );
    }();
    _persistInFlight = operation;
    try {
      await operation;
      return upserted;
    } finally {
      if (_persistInFlight == operation) {
        _persistInFlight = null;
      }
    }
  }

  Future<void> _initialTodayRefresh() async {
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!mounted) {
      return;
    }
    await _todayCubit?.refresh();
    _logColdStartReadyIfNeeded();
  }

  void _logColdStartPhase(
    String phase, {
    Map<String, Object?> details = const {},
  }) {
    final stopwatch = _coldStartStopwatch;
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

  void _logColdStartReadyIfNeeded() {
    if (_coldStartReadyLogged || _coldStartStopwatch == null) {
      return;
    }
    final cubit = _todayCubit;
    if (cubit == null || cubit.state.status == TodayStatus.loading) {
      return;
    }
    _coldStartReadyLogged = true;
    _coldStartStopwatch!.stop();
    _logColdStartPhase(
      'cold start UI READY',
      details: {
        'steps': cubit.state.steps,
        'status': cubit.state.status.name,
      },
    );
  }

  void _onTodayCubitReady(TodayCubit cubit) {
    _todayCubit = cubit;
    if (widget.enableLiveStepPipeline) {
      unawaited(_ensureLivePipelineAttached());
    } else {
      unawaited(_initialTodayRefresh());
    }
  }

  void _onHistoryCubitReady(HistoryCubit cubit) {
    _historyCubit = cubit;
  }

  void _onMyDataCubitReady(MyDataCubit cubit) {
    _myDataCubit = cubit;
  }

  /// First launch or hot-reload cubit recreate — never overwrite live total with
  /// a stale SQLite-only [TodayCubit.refresh].
  Future<void> _ensureLivePipelineAttached() async {
    if (!_livePipelineStarted) {
      await _startLivePipelineFirstTime();
      return;
    }
    await _reattachLivePipeline();
  }

  /// Cold-start live pipeline (permission granted):
  /// foreground backfill → SQLite baseline via [TodayCubit.refresh] → live attach.
  ///
  /// See Today Display Truth Model in
  /// `_bmad-output/planning-artifacts/architecture.md`.
  Future<void> _startLivePipelineFirstTime() async {
    if (!widget.enableLiveStepPipeline) {
      return;
    }
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!mounted) {
      return;
    }
    await _bindLiveMonitorToToday();
    if (!mounted) {
      return;
    }
    _livePipelineStarted = true;
    _logColdStartPhase(
      'cold start pipeline DONE',
      details: {
        'monitorRunning': widget.deps.liveStepMonitor.isRunning,
        'monitorTotal': widget.deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
      },
    );
    _logColdStartReadyIfNeeded();
    _startActivityBasedPersist();
  }

  Future<void> _reattachLivePipeline() async {
    if (!mounted) {
      return;
    }
    await _bindLiveMonitorToToday();
  }

  Future<void> _bindLiveMonitorToToday({bool foregroundCatchUp = false}) async {
    if (!await widget.deps.activityPermissionGranted()) {
      livePipelineLog('app', 'bind SKIPPED reason=no_permission');
      await _todayCubit?.refresh();
      return;
    }

    final monitor = widget.deps.liveStepMonitor;
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }

    // SQLite daily sum before live overlay (Today Display Truth Model).
    if (!foregroundCatchUp) {
      await _todayCubit?.refresh(silent: true);
    }

    if (foregroundCatchUp) {
      await _todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        foregroundCatchUp: true,
      );
      // When catch-up was skipped (already aligned), replayLatest re-attaches
      // the stream without triggering a redundant GoalRing count-up animation.
      final catchUpActive = _todayCubit?.state.foregroundCatchUp ?? false;
      _todayCubit?.attachLiveMonitor(
        monitor,
        replayLatest: !catchUpActive,
      );
    } else {
      _todayCubit?.attachLiveMonitor(monitor);
      await _todayCubit?.syncSteps(
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
        'cubitSteps': _todayCubit?.state.steps,
        'catchUp': _todayCubit?.state.foregroundCatchUp ?? false,
      },
    );
    // Cold-start bind already ran refresh(silent); resume catch-up skips it.
    if (foregroundCatchUp) {
      await _todayCubit?.refreshMetadata();
    } else {
      _logColdStartReadyIfNeeded();
    }
  }

  void _startActivityBasedPersist() {
    if (!widget.enablePeriodicPersist) {
      return;
    }
    final monitor = widget.deps.liveStepMonitor;
    monitor.onActivityIdle = () {
      unawaited(_onActivityIdlePersist());
    };

    final maxStaleness = widget.maxPersistStaleness;
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = Timer.periodic(maxStaleness, (_) {
      if (shouldTriggerStalenessPersist(
        lastPersistAt: _lastPersistAt,
        now: DateTime.now(),
        maxStaleness: maxStaleness,
      )) {
        unawaited(_runPersistIfNotInFlight());
      }
    });
  }

  void _stopActivityBasedPersist() {
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = null;
    widget.deps.liveStepMonitor.onActivityIdle = null;
  }

  void _onOnboardingComplete() {
    setState(() {
      _showMainShell = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(
        userPreferences: widget.deps.userPreferences,
        initialPreference: widget.deps.initialTheme,
        initialAccentPreset: widget.deps.initialAccentPreset,
      ),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'ASTRA',
            theme: buildAstraLightTheme(preset: themeState.accentPreset),
            darkTheme: buildAstraDarkTheme(preset: themeState.accentPreset),
            themeMode: themeState.materialThemeMode,
            themeAnimationDuration: const Duration(milliseconds: 120),
            home: _showMainShell
                ? AppScaffold(
                    deps: widget.deps,
                    foregroundBackfill: widget.deps.initialOnboardingComplete
                        ? _foregroundBackfill
                        : null,
                    onDebugSnackBarReady: (show) => _showDebugSnackBar = show,
                    onTodayCubitReady: _onTodayCubitReady,
                    onTodayCubitDisposed: () => _todayCubit = null,
                    onHistoryCubitReady: _onHistoryCubitReady,
                    onHistoryCubitDisposed: () => _historyCubit = null,
                    onMyDataCubitReady: _onMyDataCubitReady,
                    onMyDataCubitDisposed: () => _myDataCubit = null,
                    createTodayCubit: widget.createTodayCubit,
                    createHistoryCubit: widget.createHistoryCubit,
                    createMyDataCubit: widget.createMyDataCubit,
                  )
                : OnboardingFlow(
                    deps: widget.deps,
                    onComplete: _onOnboardingComplete,
                    createCubit: widget.createOnboardingCubit,
                  ),
          );
        },
      ),
    );
  }
}
