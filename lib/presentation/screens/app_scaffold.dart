import 'dart:async';

import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/di/app_dependencies.dart';
import '../coordinators/app_cubit_coordinator.dart';
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

class _KeepAliveHistoryTab extends StatefulWidget {
  const _KeepAliveHistoryTab({required this.cubit});

  final HistoryCubit cubit;

  @override
  State<_KeepAliveHistoryTab> createState() => _KeepAliveHistoryTabState();
}

class _KeepAliveHistoryTabState extends State<_KeepAliveHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: widget.cubit,
      child: const HistoryScreen(),
    );
  }
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;
  late final AppCubitCoordinator _coordinator;
  bool _historyTabMounted = false;
  late final List<Widget> _tabScreens;
  final _menuNavigatorKey = GlobalKey<NavigatorState>();
  MenuHubDestination? _menuStackTopDestination;

  void _mountHistoryTabIfNeeded() {
    if (_historyTabMounted) {
      return;
    }
    final cubit = _coordinator.ensureHistory();
    _tabScreens[1] = RepaintBoundary(
      child: _KeepAliveHistoryTab(cubit: cubit),
    );
    _historyTabMounted = true;
  }

  @override
  void initState() {
    super.initState();
    _coordinator = AppCubitCoordinator(
      deps: widget.deps,
      createTodayCubit: widget.createTodayCubit,
      createHistoryCubit: widget.createHistoryCubit,
      createMyDataCubit: widget.createMyDataCubit,
      createProfileCubit: widget.createProfileCubit,
      onHistoryFirstCreated: widget.onHistoryCubitReady,
    );
    widget.onTodayCubitReady?.call(_coordinator.today);
    widget.onMyDataCubitReady?.call(_coordinator.myData);
    widget.onProfileCubitReady?.call(_coordinator.profile);
    _tabScreens = [
      RepaintBoundary(
        child: BlocProvider.value(
          value: _coordinator.today,
          child: const TodayScreen(),
        ),
      ),
      const RepaintBoundary(child: SizedBox.shrink()),
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

  @override
  void dispose() {
    widget.deps.backgroundCollector.registerOnIngestionComplete(null);
    widget.onTodayCubitDisposed?.call();
    widget.onHistoryCubitDisposed?.call();
    widget.onMyDataCubitDisposed?.call();
    widget.onProfileCubitDisposed?.call();
    _coordinator.dispose();
    super.dispose();
  }

  void _onIngestionComplete() {
    _coordinator.onIngestionComplete(
      historyTabActive:
          _selectedIndex == 1 && _coordinator.historyIfCreated != null,
    );
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final returningToToday = index == 0 && _selectedIndex != 0;
    final openingTrends = index == 1 && _selectedIndex != 1;
    if (openingTrends) {
      _mountHistoryTabIfNeeded();
    }
    setState(() {
      _selectedIndex = index;
    });
    if (returningToToday) {
      _coordinator.onReturnToToday();
    }
    if (openingTrends) {
      unawaited(_coordinator.ensureHistory().refresh());
    }
  }

  void _clearMenuDestinationGuard(MenuHubDestination destination) {
    if (_menuStackTopDestination == destination) {
      _menuStackTopDestination = null;
    }
  }

  Widget _wrapMenuPushRoute(MenuHubDestination destination, Widget child) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _clearMenuDestinationGuard(destination);
        }
      },
      child: child,
    );
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
        unawaited(_coordinator.profile.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/profile'),
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return _wrapMenuPushRoute(
                destination,
                BlocProvider.value(
                  value: _coordinator.profile,
                  child: SecondaryScreenShell(
                    title: l10n.menuProfile,
                    child: const ProfileScreen(showInlineTitle: false),
                  ),
                ),
              );
            },
          ),
        );
      case MenuHubDestination.data:
        unawaited(_coordinator.myData.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/data'),
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return _wrapMenuPushRoute(
                destination,
                BlocProvider.value(
                  value: _coordinator.myData,
                  child: SecondaryScreenShell(
                    title: l10n.menuData,
                    child: const MyDataScreen(showInlineTitle: false),
                  ),
                ),
              );
            },
          ),
        );
      case MenuHubDestination.settings:
        unawaited(_coordinator.profile.refresh());
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/settings'),
            builder: (context) => _wrapMenuPushRoute(
              destination,
              BlocProvider.value(
                value: _coordinator.profile,
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
      case MenuHubDestination.about:
        pushFuture = navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'menu/about'),
            builder: (context) => _wrapMenuPushRoute(
              destination,
              const AboutScreen(),
            ),
          ),
        );
    }

    unawaited(
      pushFuture.whenComplete(() {
        if (mounted) {
          _clearMenuDestinationGuard(destination);
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
