import 'dart:async';

import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/di/app_dependencies.dart';
import '../cubits/history_cubit.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/today_cubit.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/secondary_screen_shell.dart';
import 'about_screen.dart';
import 'history_screen.dart';
import 'menu_hub_screen.dart';
import 'my_data_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
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
  late final List<Widget> _tabScreens;
  final _menuNavigatorKey = GlobalKey<NavigatorState>();
  MenuHubDestination? _menuStackTopDestination;

  @override
  void initState() {
    super.initState();
    _todayCubit =
        widget.createTodayCubit?.call(widget.deps) ??
        TodayCubit(
          stepAggregation: widget.deps.stepAggregation,
          userSettings: widget.deps.userSettings,
          userHealthMetrics: widget.deps.userHealthMetrics,
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
          stepAggregation: widget.deps.stepAggregation,
          userHealthMetrics: widget.deps.userHealthMetrics,
        );
    _myDataCubit =
        widget.createMyDataCubit?.call(widget.deps) ??
        MyDataCubit(
          stepAggregation: widget.deps.stepAggregation,
          csvService: widget.deps.csvService,
          stepIngestion: widget.deps.stepIngestion,
          userSettings: widget.deps.userSettings,
          userHealthMetrics: widget.deps.userHealthMetrics,
          clock: widget.deps.timeProvider,
          databasePath: widget.deps.databasePath,
          activityPermissionGranted: widget.deps.activityPermissionGranted,
          postImportRefresh: () async {
            await _todayCubit.refreshMetadata();
            await _historyCubit.refresh(silent: true);
            await _myDataCubit.refresh(silent: true);
          },
          postPurgeRefresh: _runPostPurgeRefresh,
          postGoalUpdate: () async {
            await _todayCubit.refreshMetadata();
            await _historyCubit.refreshGoal();
          },
        );
    _profileCubit =
        widget.createProfileCubit?.call(widget.deps) ??
        ProfileCubit(
          userSettings: widget.deps.userSettings,
          userHealthMetrics: widget.deps.userHealthMetrics,
          notificationService: widget.deps.notificationService,
          postDisplayNameUpdate: () async {
            await _todayCubit.refreshMetadata();
          },
        );
    widget.onTodayCubitReady?.call(_todayCubit);
    widget.onHistoryCubitReady?.call(_historyCubit);
    widget.onMyDataCubitReady?.call(_myDataCubit);
    widget.onProfileCubitReady?.call(_profileCubit);
    _tabScreens = [
      RepaintBoundary(
        child: BlocProvider.value(
          value: _todayCubit,
          child: const TodayScreen(),
        ),
      ),
      RepaintBoundary(
        child: BlocProvider.value(
          value: _historyCubit,
          child: const HistoryScreen(),
        ),
      ),
      RepaintBoundary(
        child: Navigator(
          key: _menuNavigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => MenuHubScreen(
              onDestinationSelected: _onMenuDestinationSelected,
            ),
          ),
        ),
      ),
    ];
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

  Future<void> _runPostPurgeRefresh() async {
    var phase = '';
    try {
      phase = 'clearLastDisplayedSteps';
      await widget.deps.userSettings.clearLastDisplayedSteps();
      // TODO(refactor): If the widget is unmounted mid-flux, we return silently to avoid StateError.
      // Trade-off: MyDataCubit might assume a full success while some late refreshes were skipped.
      // Considered acceptable as the database purge itself is already complete at this stage.
      if (!mounted) return;

      phase = 'reconcileFromDatabase';
      await widget.deps.liveStepMonitor.reconcileFromDatabase();
      if (!mounted) return;

      phase = 'todayRefresh';
      await _todayCubit.refresh(silent: true);
      if (!mounted) return;

      phase = 'todaySyncSteps';
      await _todayCubit.syncSteps(
        widget.deps.liveStepMonitor.currentTodaySteps,
      );
      if (!mounted) return;

      phase = 'todayRefreshMetadata';
      await _todayCubit.refreshMetadata();
      if (!mounted) return;

      phase = 'historyRefresh';
      await _historyCubit.refresh(silent: true);
      if (!mounted) return;

      phase = 'myDataRefresh';
      await _myDataCubit.refresh(silent: true);
      if (!mounted) return;

      unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'AppScaffold.postPurgeRefresh failed at $phase: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
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
  }

  void _onMenuDestinationSelected(MenuHubDestination destination) {
    final navigator = _menuNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    if (_menuStackTopDestination == destination) {
      return;
    }

    _menuStackTopDestination = destination;
    final Future<void> pushFuture;
    switch (destination) {
      case MenuHubDestination.profile:
        unawaited(_profileCubit.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/profile'),
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return BlocProvider.value(
                value: _profileCubit,
                child: SecondaryScreenShell(
                  title: l10n.menuProfile,
                  child: const ProfileScreen(showInlineTitle: false),
                ),
              );
            },
          ),
        );
      case MenuHubDestination.data:
        unawaited(_myDataCubit.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/data'),
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return BlocProvider.value(
                value: _myDataCubit,
                child: SecondaryScreenShell(
                  title: l10n.menuData,
                  child: const MyDataScreen(showInlineTitle: false),
                ),
              );
            },
          ),
        );
      case MenuHubDestination.settings:
        unawaited(_profileCubit.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/settings'),
            builder: (context) => BlocProvider.value(
              value: _profileCubit,
              child: const SettingsScreen(),
            ),
          ),
        );
      case MenuHubDestination.about:
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/about'),
            builder: (context) => const AboutScreen(),
          ),
        );
    }

    unawaited(
      pushFuture.whenComplete(() {
        if (mounted && _menuStackTopDestination == destination) {
          _menuStackTopDestination = null;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabScreens,
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _onDestinationSelected,
      ),
    );
  }
}
