import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/live_step_monitor.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/cubits/history_cubit.dart';
import 'presentation/cubits/my_data_cubit.dart';
import 'presentation/cubits/today_cubit.dart';
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
  });

  final AppDependencies deps;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
  createOnboardingCubit;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
  final HistoryCubit Function(AppDependencies deps)? createHistoryCubit;
  final MyDataCubit Function(AppDependencies deps)? createMyDataCubit;
  final bool enablePeriodicPersist;
  final bool enableLiveStepPipeline;

  @override
  State<AstraApp> createState() => _AstraAppState();
}

/// Safety net: persist at least this often during continuous walking.
const kMaxPersistStaleness = Duration(minutes: 5);

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
  Future<void>? _persistInFlight;

  @override
  void initState() {
    super.initState();
    _showMainShell = widget.deps.initialOnboardingComplete;
    WidgetsBinding.instance.addObserver(this);
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
      unawaited(_onAppBackgrounded());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_onAppForegrounded());
    }
  }

  Future<void> _onAppBackgrounded() async {
    await _persistOnPause();
    if (!_showMainShell) {
      return;
    }
    _stopActivityBasedPersist();
    final healthFgs = widget.deps.healthForegroundCoordinator;
    if (widget.enableLiveStepPipeline) {
      await widget.deps.liveStepMonitor.stop();
    }
    await healthFgs.setUiActive(false);
    await healthFgs.startHealthCollectionService();
  }

  Future<void> _onAppForegrounded() async {
    final healthFgs = widget.deps.healthForegroundCoordinator;
    await healthFgs.stopHealthCollectionService();
    await healthFgs.setUiActive(true);
    await widget.deps.dataLifecycleService.runMaintenance();
    await _collectAndRefreshToday();
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
  Future<int> _runPersistCycle({required bool enableGoalNotification}) async {
    final monitor = widget.deps.liveStepMonitor;
    final collector = widget.deps.backgroundCollector;
    await monitor.beginReconcile();
    try {
      final upserted = await collector.collectOnce(
        maxReadingsPerSource: _persistMaxReadingsPerSource,
        enableGoalNotification: enableGoalNotification,
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

  Future<void> _collectAndRefreshToday() async {
    if (widget.enableLiveStepPipeline) {
      final monitor = widget.deps.liveStepMonitor;
      if (_livePipelineStarted && !monitor.isRunning) {
        await monitor.restart();
      }
      await _enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: true,
      );
    } else {
      await _enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: true,
      );
    }
    await _todayCubit?.refreshMetadata();
    await _historyCubit?.refresh(silent: true);
    await _myDataCubit?.refresh(silent: true);
  }

  Future<void> _initialTodayRefresh() async {
    await _foregroundBackfill;
    if (!mounted) {
      return;
    }
    await _todayCubit?.refresh();
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
    if (!mounted) {
      return;
    }
    await _bindLiveMonitorToToday();
    if (!mounted) {
      return;
    }
    _livePipelineStarted = true;
    _startActivityBasedPersist();
  }

  Future<void> _reattachLivePipeline() async {
    if (!mounted) {
      return;
    }
    await _bindLiveMonitorToToday();
  }

  Future<void> _bindLiveMonitorToToday() async {
    if (!await widget.deps.activityPermissionGranted()) {
      await _todayCubit?.refresh();
      return;
    }

    // SQLite daily sum before live overlay (Today Display Truth Model).
    await _todayCubit?.refresh(silent: true);

    final monitor = widget.deps.liveStepMonitor;
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }

    _todayCubit?.attachLiveMonitor(monitor);
    await _todayCubit?.syncSteps(monitor.currentTodaySteps);
    await _todayCubit?.refreshMetadata();
  }

  void _startActivityBasedPersist() {
    if (!widget.enablePeriodicPersist) {
      return;
    }
    final monitor = widget.deps.liveStepMonitor;
    monitor.onActivityIdle = () {
      unawaited(_runPersistIfNotInFlight());
    };

    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = Timer.periodic(kMaxPersistStaleness, (_) {
      final lastPersist = _lastPersistAt;
      if (lastPersist == null ||
          DateTime.now().difference(lastPersist) >= kMaxPersistStaleness) {
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
