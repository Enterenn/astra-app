import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/di/app_dependencies.dart';
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
    this.createTodayCubit,
    super.key,
  });

  final AppDependencies deps;
  final Future<int>? foregroundBackfill;
  final ValueChanged<TodayCubit>? onTodayCubitReady;
  final VoidCallback? onTodayCubitDisposed;
  final TodayCubit Function(AppDependencies deps)? createTodayCubit;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;
  late final TodayCubit _todayCubit;

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
    widget.onTodayCubitReady?.call(_todayCubit);
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
    if (!mounted) {
      return;
    }
    await _todayCubit.refresh();
  }

  @override
  void dispose() {
    widget.deps.backgroundCollector.registerOnIngestionComplete(null);
    widget.onTodayCubitDisposed?.call();
    _todayCubit.close();
    super.dispose();
  }

  void _onIngestionComplete() {
    unawaited(_todayCubit.refreshMetadata());
  }

  void _onDestinationSelected(int index) {
    final returningToToday = index == 0 && _selectedIndex != 0;
    setState(() {
      _selectedIndex = index;
    });
    if (returningToToday) {
      unawaited(_todayCubit.refreshMetadata());
    }
  }

  void _navigateToMyData() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      0 => BlocProvider.value(
        value: _todayCubit,
        child: TodayScreen(onNavigateToMyData: _navigateToMyData),
      ),
      1 => const HistoryScreen(),
      2 => const MyDataScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
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
