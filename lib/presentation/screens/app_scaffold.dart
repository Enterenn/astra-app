import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/di/app_dependencies.dart';
import '../../dev/chart_benchmark_dev_fab.dart';
import '../cubits/history_cubit.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/today_cubit.dart';
import '../widgets/app_bottom_nav.dart';
import 'history_screen.dart';
import 'my_data_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.deps,
    this.foregroundBackfill,
    this.onTodayCubitReady,
    this.onTodayCubitDisposed,
    this.onHistoryCubitReady,
    this.onHistoryCubitDisposed,
    this.onMyDataCubitReady,
    this.onMyDataCubitDisposed,
    this.onProfileCubitReady,
    this.onProfileCubitDisposed,
    this.createTodayCubit,
    this.createHistoryCubit,
    this.createMyDataCubit,
    this.createProfileCubit,
    super.key,
  });

  final AppDependencies deps;
  final Future<int>? foregroundBackfill;
  final ValueChanged<TodayCubit>? onTodayCubitReady;
  final VoidCallback? onTodayCubitDisposed;
  final ValueChanged<HistoryCubit>? onHistoryCubitReady;
  final VoidCallback? onHistoryCubitDisposed;
  final ValueChanged<MyDataCubit>? onMyDataCubitReady;
  final VoidCallback? onMyDataCubitDisposed;
  final ValueChanged<ProfileCubit>? onProfileCubitReady;
  final VoidCallback? onProfileCubitDisposed;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
  final HistoryCubit Function(AppDependencies deps)? createHistoryCubit;
  final MyDataCubit Function(AppDependencies deps)? createMyDataCubit;
  final ProfileCubit Function(AppDependencies deps)? createProfileCubit;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;
  late final TodayCubit _todayCubit;
  late final HistoryCubit _historyCubit;
  late final MyDataCubit _myDataCubit;
  late final ProfileCubit _profileCubit;

  @override
  void initState() {
    super.initState();
    _todayCubit =
        widget.createTodayCubit?.call(widget.deps) ??
        TodayCubit(
          stepRepository: widget.deps.stepRepository,
          userPreferences: widget.deps.userPreferences,
          clock: widget.deps.timeProvider,
          activityPermissionGranted: widget.deps.activityPermissionGranted,
          postGoalUpdate: () async {
            await _historyCubit.refreshGoal();
            await _myDataCubit.refresh(silent: true);
          },
        );
    _historyCubit =
        widget.createHistoryCubit?.call(widget.deps) ??
        HistoryCubit(
          stepRepository: widget.deps.stepRepository,
          userPreferences: widget.deps.userPreferences,
        );
    _myDataCubit =
        widget.createMyDataCubit?.call(widget.deps) ??
        MyDataCubit(
          stepRepository: widget.deps.stepRepository,
          userPreferences: widget.deps.userPreferences,
          capabilityEvaluator: widget.deps.backgroundHealthCapabilityEvaluator,
          clock: widget.deps.timeProvider,
          databasePath: widget.deps.databasePath,
          activityPermissionGranted: widget.deps.activityPermissionGranted,
          postImportRefresh: () async {
            await _todayCubit.refreshMetadata();
            await _historyCubit.refresh(silent: true);
            await _myDataCubit.refresh(silent: true);
          },
          postPurgeRefresh: () async {
            await widget.deps.liveStepMonitor.reconcileFromDatabase();
            await _todayCubit.refresh(silent: true);
            await _todayCubit.syncSteps(
              widget.deps.liveStepMonitor.currentTodaySteps,
            );
            await _todayCubit.refreshMetadata();
            await _historyCubit.refresh(silent: true);
            await _myDataCubit.refresh(silent: true);
            unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
          },
          postGoalUpdate: () async {
            await _todayCubit.refreshMetadata();
            await _historyCubit.refreshGoal();
          },
        );
    _profileCubit =
        widget.createProfileCubit?.call(widget.deps) ??
        ProfileCubit(
          userPreferences: widget.deps.userPreferences,
          notificationService: widget.deps.notificationService,
          postDisplayNameUpdate: () async {
            await _todayCubit.refreshMetadata();
          },
        );
    widget.onTodayCubitReady?.call(_todayCubit);
    widget.onHistoryCubitReady?.call(_historyCubit);
    widget.onMyDataCubitReady?.call(_myDataCubit);
    widget.onProfileCubitReady?.call(_profileCubit);
    widget.deps.backgroundCollector.registerOnIngestionComplete(
      _onIngestionComplete,
    );
    unawaited(_initialRefresh());
  }

  Future<void> _initialRefresh() async {
    final backfill = widget.foregroundBackfill;
    if (backfill != null) {
      await backfill;
    }
  }

  @override
  void dispose() {
    widget.deps.backgroundCollector.registerOnIngestionComplete(null);
    widget.onTodayCubitDisposed?.call();
    widget.onHistoryCubitDisposed?.call();
    widget.onMyDataCubitDisposed?.call();
    widget.onProfileCubitDisposed?.call();
    _todayCubit.close();
    _historyCubit.close();
    _myDataCubit.close();
    _profileCubit.close();
    super.dispose();
  }

  void _onIngestionComplete() {
    unawaited(_todayCubit.refreshMetadata());
    unawaited(_historyCubit.refresh(silent: true));
    unawaited(_myDataCubit.refresh(silent: true));
  }

  void _onDestinationSelected(int index) {
    final returningToToday = index == 0 && _selectedIndex != 0;
    final openingTrends = index == 1 && _selectedIndex != 1;
    final openingData = index == 2 && _selectedIndex != 2;
    final openingProfile = index == 3 && _selectedIndex != 3;
    setState(() {
      _selectedIndex = index;
    });
    if (returningToToday) {
      unawaited(_todayCubit.refreshMetadata());
      unawaited(_historyCubit.refreshGoal());
    }
    if (openingTrends) {
      unawaited(_historyCubit.refresh());
    }
    if (openingData) {
      unawaited(_myDataCubit.refresh());
    }
    if (openingProfile) {
      unawaited(_profileCubit.refresh());
    }
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      0 => BlocProvider.value(
        value: _todayCubit,
        child: const TodayScreen(),
      ),
      1 => BlocProvider.value(
        value: _historyCubit,
        child: const HistoryScreen(),
      ),
      2 => BlocProvider.value(
        value: _myDataCubit,
        child: const MyDataScreen(),
      ),
      3 => BlocProvider.value(
        value: _profileCubit,
        child: const ProfileScreen(),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      floatingActionButton: kDebugMode && _selectedIndex == 1
          ? ChartBenchmarkDevFab(deps: widget.deps)
          : null,
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _buildScreen(_selectedIndex),
        ),
      ),
      // Floating pill colors use accentPrimary until Story 5.8 preset wiring.
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _onDestinationSelected,
      ),
    );
  }
}
