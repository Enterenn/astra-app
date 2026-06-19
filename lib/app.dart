import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/app_lifecycle_coordinator.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/cubits/units_cubit.dart';
import 'presentation/cubits/history_cubit.dart';
import 'presentation/cubits/my_data_cubit.dart';
import 'presentation/cubits/today_cubit.dart';
import 'presentation/onboarding/onboarding_flow.dart';
import 'presentation/screens/app_scaffold.dart';

export 'core/services/app_lifecycle_coordinator.dart'
    show
        kMaxPersistStaleness,
        kResumePhoneCatchUpTimeout,
        runSerializedLifecycleTransition,
        shouldRunResumePhoneCatchUp,
        shouldRunResumePhonePeek,
        shouldTriggerStalenessPersist;

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

class _AstraAppState extends State<AstraApp> with WidgetsBindingObserver {
  late bool _showMainShell;

  AppLifecycleCoordinator get _coordinator => widget.deps.appLifecycleCoordinator;

  @override
  void initState() {
    super.initState();
    _showMainShell = widget.deps.initialOnboardingComplete;
    WidgetsBinding.instance.addObserver(this);
    _coordinator.bindToWidget(
      isMounted: () => mounted,
      showMainShell: () => _showMainShell,
      enablePeriodicPersist: widget.enablePeriodicPersist,
      enableLiveStepPipeline: widget.enableLiveStepPipeline,
      maxPersistStaleness: widget.maxPersistStaleness,
      minPauseForPhoneCatchUp: widget.minPauseForPhoneCatchUp,
      initialShowMainShell: _showMainShell,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_coordinator.onLifecycleStatePaused());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_coordinator.onLifecycleStateResumed());
    }
  }

  void _onTodayCubitReady(TodayCubit cubit) {
    _coordinator.onTodayCubitReady(cubit);
  }

  void _onHistoryCubitReady(HistoryCubit cubit) {
    _coordinator.onHistoryCubitReady(cubit);
  }

  void _onMyDataCubitReady(MyDataCubit cubit) {
    _coordinator.onMyDataCubitReady(cubit);
  }

  void _onOnboardingComplete() {
    setState(() {
      _showMainShell = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeCubit(
            userPreferences: widget.deps.userPreferences,
            initialPreference: widget.deps.initialTheme,
            initialAccentPreset: widget.deps.initialAccentPreset,
          ),
        ),
        BlocProvider(
          create: (_) => UnitsCubit(
            userPreferences: widget.deps.userPreferences,
            initialDistanceUnit: widget.deps.initialDistanceUnit,
            initialWeightUnit: widget.deps.initialWeightUnit,
            initialHeightUnit: widget.deps.initialHeightUnit,
          ),
        ),
      ],
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
                        ? _coordinator.foregroundBackfill
                        : null,
                    onTodayCubitReady: _onTodayCubitReady,
                    onTodayCubitDisposed: () =>
                        _coordinator.bindTodayCubit(null),
                    onHistoryCubitReady: _onHistoryCubitReady,
                    onHistoryCubitDisposed: () =>
                        _coordinator.bindHistoryCubit(null),
                    onMyDataCubitReady: _onMyDataCubitReady,
                    onMyDataCubitDisposed: () =>
                        _coordinator.bindMyDataCubit(null),
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
