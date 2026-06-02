import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/di/app_dependencies.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/cubits/history_cubit.dart';
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
    this.enablePeriodicPersist = true,
    this.enableLiveStepPipeline = true,
  });

  final AppDependencies deps;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
  createOnboardingCubit;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
  final HistoryCubit Function(AppDependencies deps)? createHistoryCubit;
  final bool enablePeriodicPersist;
  final bool enableLiveStepPipeline;

  @override
  State<AstraApp> createState() => _AstraAppState();
}

class _AstraAppState extends State<AstraApp> with WidgetsBindingObserver {
  static const _persistInterval = Duration(seconds: 60);

  /// Must cover [LiveStepMonitor.maxBufferedReadings] so periodic persist
  /// normalizes every buffered phone reading in one collect.
  static const _persistMaxReadingsPerSource = 250;

  late bool _showMainShell;
  TodayCubit? _todayCubit;
  HistoryCubit? _historyCubit;
  late final Future<int> _foregroundBackfill;
  Timer? _persistTimer;
  bool _livePipelineStarted = false;
  Future<void>? _backgroundPersistInFlight;

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
    _persistTimer?.cancel();
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
    _persistTimer?.cancel();
    _persistTimer = null;
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
    await _collectAndRefreshToday();
    if (_livePipelineStarted && widget.enablePeriodicPersist) {
      _startPeriodicPersist();
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

    if (_backgroundPersistInFlight != null) {
      return _backgroundPersistInFlight;
    }

    _backgroundPersistInFlight = _persistOnPauseImpl();
    try {
      await _backgroundPersistInFlight;
    } finally {
      _backgroundPersistInFlight = null;
    }
  }

  Future<void> _persistOnPauseImpl() async {
    if (widget.enableLiveStepPipeline) {
      if (!_livePipelineStarted) {
        return;
      }
      await _runPersistCycle(enableGoalNotification: false);
      return;
    }

    await widget.deps.backgroundCollector.collectOnce(
      enableGoalNotification: false,
    );
  }

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
      return upserted;
    } finally {
      monitor.endReconcile();
    }
  }

  Future<void> _collectAndRefreshToday() async {
    final pendingPausePersist = _backgroundPersistInFlight;
    if (pendingPausePersist != null) {
      await pendingPausePersist;
    }

    if (widget.enableLiveStepPipeline) {
      final monitor = widget.deps.liveStepMonitor;
      if (_livePipelineStarted && !monitor.isRunning) {
        await monitor.start();
        await monitor.reconcileFromDatabase();
      }
      await _runPersistCycle(enableGoalNotification: false);
      await _todayCubit?.syncSteps(monitor.currentTodaySteps);
    } else {
      await widget.deps.backgroundCollector.collectOnce(
        enableGoalNotification: false,
      );
      await _todayCubit?.refresh(silent: true);
    }
    await _todayCubit?.refreshMetadata();
    await _historyCubit?.refresh(silent: true);
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

  /// First launch or hot-reload cubit recreate — never overwrite live total with
  /// a stale SQLite-only [TodayCubit.refresh].
  Future<void> _ensureLivePipelineAttached() async {
    if (!_livePipelineStarted) {
      await _startLivePipelineFirstTime();
      return;
    }
    await _reattachLivePipeline();
  }

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
    _startPeriodicPersist();
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

    final monitor = widget.deps.liveStepMonitor;
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }

    _todayCubit?.attachLiveMonitor(monitor);
    await _todayCubit?.syncSteps(monitor.currentTodaySteps);
    await _todayCubit?.refreshMetadata();
  }

  void _startPeriodicPersist() {
    if (!widget.enablePeriodicPersist) {
      return;
    }
    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(_persistInterval, (_) {
      unawaited(_runPersistCycle(enableGoalNotification: false));
    });
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
      ),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'ASTRA',
            theme: buildAstraLightTheme(),
            darkTheme: buildAstraDarkTheme(),
            themeMode: themeState.materialThemeMode,
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
                    createTodayCubit: widget.createTodayCubit,
                    createHistoryCubit: widget.createHistoryCubit,
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
