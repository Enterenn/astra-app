import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/di/app_dependencies.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/cubits/today_cubit.dart';
import 'presentation/onboarding/onboarding_flow.dart';
import 'presentation/screens/app_scaffold.dart';

class AstraApp extends StatefulWidget {
  const AstraApp({
    super.key,
    required this.deps,
    this.createOnboardingCubit,
    this.createTodayCubit,
    this.enablePeriodicPersist = true,
    this.enableLiveStepPipeline = true,
  });

  final AppDependencies deps;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
  createOnboardingCubit;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
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
  late final Future<int> _foregroundBackfill;
  Timer? _persistTimer;
  bool _livePipelineStarted = false;

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
    if (state == AppLifecycleState.resumed) {
      unawaited(_collectAndRefreshToday());
    }
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
    if (widget.enableLiveStepPipeline) {
      await _runPersistCycle(enableGoalNotification: false);
    } else {
      await widget.deps.backgroundCollector.collectOnce(
        enableGoalNotification: false,
      );
    }
    await _todayCubit?.refreshMetadata();
  }

  void _onTodayCubitReady(TodayCubit cubit) {
    _todayCubit = cubit;
    unawaited(_maybeStartLivePipeline());
  }

  Future<void> _maybeStartLivePipeline() async {
    if (!widget.enableLiveStepPipeline || _livePipelineStarted) {
      return;
    }
    await _foregroundBackfill;
    if (!mounted) {
      return;
    }
    if (!await widget.deps.activityPermissionGranted()) {
      return;
    }

    final monitor = widget.deps.liveStepMonitor;
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }

    _todayCubit?.attachLiveMonitor(monitor);
    _livePipelineStarted = true;
    _startPeriodicPersist();
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
                    createTodayCubit: widget.createTodayCubit,
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
