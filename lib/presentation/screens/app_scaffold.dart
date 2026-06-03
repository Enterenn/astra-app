import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/di/app_dependencies.dart';
import '../../dev/chart_benchmark_dev_fab.dart';
import '../cubits/history_cubit.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/today_cubit.dart';
import 'history_screen.dart';
import 'my_data_screen.dart';
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
    this.createTodayCubit,
    this.createHistoryCubit,
    this.createMyDataCubit,
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
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;
  final HistoryCubit Function(AppDependencies deps)? createHistoryCubit;
  final MyDataCubit Function(AppDependencies deps)? createMyDataCubit;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;
  late final TodayCubit _todayCubit;
  late final HistoryCubit _historyCubit;
  late final MyDataCubit _myDataCubit;

  static const _labels = ['Today', 'History', 'My Data'];
  static const _icons = [
    Icons.circle_outlined,
    Icons.bar_chart_outlined,
    Icons.shield_outlined,
  ];

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
        );
    widget.onTodayCubitReady?.call(_todayCubit);
    widget.onHistoryCubitReady?.call(_historyCubit);
    widget.onMyDataCubitReady?.call(_myDataCubit);
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
    _todayCubit.close();
    _historyCubit.close();
    _myDataCubit.close();
    super.dispose();
  }

  void _onIngestionComplete() {
    unawaited(_todayCubit.refreshMetadata());
    unawaited(_historyCubit.refresh(silent: true));
    unawaited(_myDataCubit.refresh(silent: true));
  }

  void _onDestinationSelected(int index) {
    final returningToToday = index == 0 && _selectedIndex != 0;
    final openingHistory = index == 1 && _selectedIndex != 1;
    final openingMyData = index == 2 && _selectedIndex != 2;
    setState(() {
      _selectedIndex = index;
    });
    if (returningToToday) {
      unawaited(_todayCubit.refreshMetadata());
      unawaited(_historyCubit.refreshGoal());
    }
    if (openingHistory) {
      unawaited(_historyCubit.refresh());
    }
    if (openingMyData) {
      unawaited(_myDataCubit.refresh());
    }
  }

  void _navigateToMyData() {
    setState(() {
      _selectedIndex = 2;
    });
    unawaited(_myDataCubit.refresh());
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      0 => BlocProvider.value(
        value: _todayCubit,
        child: TodayScreen(onNavigateToMyData: _navigateToMyData),
      ),
      1 => BlocProvider.value(
        value: _historyCubit,
        child: const HistoryScreen(),
      ),
      2 => BlocProvider.value(
        value: _myDataCubit,
        child: MyDataScreen(clock: widget.deps.timeProvider),
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
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.borderDefault)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(
                icon: Semantics(
                  label: _labels[i],
                  child: Icon(_icons[i]),
                ),
                label: _labels[i],
                tooltip: _labels[i],
              ),
          ],
        ),
      ),
    );
  }
}
