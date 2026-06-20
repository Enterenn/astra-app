import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/locale_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_errors.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/cubits/units_cubit.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:astra_app/presentation/screens/app_scaffold.dart';
import 'package:astra_app/presentation/screens/history_screen.dart';
import 'package:astra_app/presentation/screens/menu_hub_screen.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
import 'package:astra_app/presentation/widgets/accent_preset_selector.dart';
import 'package:astra_app/presentation/widgets/app_bottom_nav.dart';
import 'package:astra_app/presentation/widgets/menu_nav_row.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';
import '../../core/time/fake_time_provider.dart';

TodayCubit _testTodayCubit(AppDependencies deps) {
  return TodayCubit(
    stepAggregation: deps.stepAggregation,
    userSettings: deps.userSettings,
    userHealthMetrics: deps.userHealthMetrics,
    clock: deps.timeProvider,
    activityPermissionGranted: () async => true,
  );
}

HistoryCubit _testHistoryCubit(AppDependencies deps) {
  return HistoryCubit(
    stepAggregation: deps.stepAggregation,
    userHealthMetrics: deps.userHealthMetrics,
  );
}

class _RefreshCountingCubit extends TodayCubit {
  _RefreshCountingCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
  }) : super(activityPermissionGranted: () async => true);

  int refreshCallCount = 0;
  int syncStepsCallCount = 0;
  int refreshMetadataCallCount = 0;

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCallCount++;
    await super.refresh(silent: silent);
  }

  @override
  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) async {
    syncStepsCallCount++;
    await super.syncSteps(
      steps,
      foregroundCatchUp: foregroundCatchUp,
      clampStaleDisplay: clampStaleDisplay,
    );
  }

  @override
  Future<void> refreshMetadata() async {
    refreshCallCount++;
    refreshMetadataCallCount++;
    if (state.status == TodayStatus.loading) {
      return;
    }
    emit(
      state.copyWith(
        isStale: state.isStale,
        lastIngestionUtc: state.lastIngestionUtc,
      ),
    );
  }
}

class _RefreshCountingHistoryCubit extends HistoryCubit {
  _RefreshCountingHistoryCubit({
    required super.stepAggregation,
    required super.userHealthMetrics,
  });

  int refreshCallCount = 0;

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCallCount++;
    await super.refresh(silent: silent);
  }
}

class _ThrowingRefreshTodayCubit extends TodayCubit {
  _ThrowingRefreshTodayCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
  }) : super(activityPermissionGranted: () async => true);

  @override
  Future<void> refresh({bool silent = true}) async {
    throw StateError('today refresh failed');
  }
}

Future<void> _pumpAppScaffold(
  WidgetTester tester,
  AppScaffold scaffold, {
  bool disableAnimations = true,
  required UserSettingsRepository userSettings,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => ThemeCubit(
                  userSettings: userSettings,
                  initialPreference: AstraThemePreference.system,
                ),
              ),
              BlocProvider(
                create: (_) => UnitsCubit(userSettings: userSettings),
              ),
              BlocProvider(
                create: (_) => LocaleCubit(userSettings: userSettings),
              ),
            ],
            child: scaffold,
          ),
        ),
      ),
    );
    await tester.pump();
  });
}

Future<void> _awaitHistoryRefresh(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
}

Future<void> _disposeScaffold(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  });
}

const _packageInfoChannel =
    MethodChannel('dev.fluttercommunity.plus/package_info');

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await setUpSqfliteFfi();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'astra_app',
          'packageName': 'com.astra.health',
          'version': '0.2.2',
          'buildNumber': '5',
          'buildSignature': '',
        };
      }
      return null;
    });
  });

  group('AppScaffold', () {
    late Database db;
    late AppDependencies deps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final userSettings = UserSettingsRepository(db);
      await userSettings.setOnboardingComplete(true);
      final userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      deps = await AppDependencies.test(
        db: db,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        timeProvider: clock,
      );
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets(
      'IndexedStack tab roots are wrapped in RepaintBoundary',
      (WidgetTester tester) async {
        await _pumpAppScaffold(
          tester,
          AppScaffold(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
          ),
          userSettings: deps.userSettings,
        );
        await tester.pump();

        final stackFinder = find.byType(IndexedStack);
        final indexedStack = tester.widget<IndexedStack>(stackFinder);
        expect(indexedStack.children.length, 3);

        expect(indexedStack.children[0], isA<RepaintBoundary>());
        expect(
          (indexedStack.children[0] as RepaintBoundary).child,
          isA<BlocProvider<TodayCubit>>(),
        );
        expect(
          find.descendant(
            of: stackFinder,
            matching: find.byType(TodayScreen),
          ),
          findsOneWidget,
        );

        expect(indexedStack.children[1], isA<RepaintBoundary>());
        expect(
          (indexedStack.children[1] as RepaintBoundary).child,
          isA<BlocProvider<HistoryCubit>>(),
        );
        await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
        await tester.pump();
        expect(
          find.descendant(
            of: stackFinder,
            matching: find.byType(HistoryScreen),
          ),
          findsOneWidget,
        );

        expect(indexedStack.children[2], isA<RepaintBoundary>());
        expect(
          (indexedStack.children[2] as RepaintBoundary).child,
          isA<Navigator>(),
        );
        await tester.tap(find.byIcon(PhosphorIconsRegular.list));
        await tester.pump();
        expect(
          find.descendant(
            of: stackFinder,
            matching: find.byType(MenuHubScreen),
          ),
          findsOneWidget,
        );

        await _disposeScaffold(tester);
      },
    );

    testWidgets(
      'tab switch with reduce motion completes without hanging',
      (WidgetTester tester) async {
        await _pumpAppScaffold(
          tester,
          AppScaffold(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
          ),
          userSettings: deps.userSettings,
        );

        expect(find.text("Today's activity"), findsNothing);
        final todayTexts = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(TodayScreen),
            matching: find.byType(Text),
          ),
        );
        expect(todayTexts.first.data, 'Steps');
        expect(
          find.descendant(
            of: find.byType(TodayScreen),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'Steps',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Steps'), findsAtLeastNWidgets(2));
        expect(find.text('Phone sensor'), findsNothing);

        expect(find.text('STEPS'), findsOneWidget);
        expect(find.text('TRENDS'), findsOneWidget);
        expect(find.text('MENU'), findsOneWidget);
        expect(find.text('TODAY'), findsNothing);
        expect(find.text('DATA'), findsNothing);
        expect(find.text('PROFILE'), findsNothing);

        await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
        await tester.pump();
        await _awaitHistoryRefresh(tester);

        expect(find.text('Trends'), findsWidgets);
        expect(find.text('7 days'), findsOneWidget);
        expect(find.text('30 days'), findsOneWidget);

        await tester.tap(find.byIcon(PhosphorIconsRegular.list));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(find.text('Menu'), findsOneWidget);
        expect(find.text('Informations'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Data'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
        expect(find.text('Achievements'), findsNothing);
        expect(find.text('Help'), findsNothing);
        expect(find.text('Storage on this device'), findsNothing);
        expect(find.text('Background'), findsNothing);
        expect(find.byIcon(PhosphorIconsFill.list), findsOneWidget);

        await _disposeScaffold(tester);
      },
    );

    testWidgets('Today dashboard survives large text scale', (
      WidgetTester tester,
    ) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
        ),
        disableAnimations: false,
        userSettings: deps.userSettings,
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(TodayScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Steps',
          ),
        ),
        findsOneWidget,
      );

      await _disposeScaffold(tester);
    });

    testWidgets('returning to Today tab triggers another refresh', (
      tester,
    ) async {
      TodayCubit? cubit;

      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: (dependencies) {
            cubit = _RefreshCountingCubit(
              stepAggregation: dependencies.stepAggregation,
              userSettings: dependencies.userSettings,
              userHealthMetrics: dependencies.userHealthMetrics,
              clock: dependencies.timeProvider,
            );
            return cubit!;
          },
          createHistoryCubit: _testHistoryCubit,
        ),
        userSettings: deps.userSettings,
      );
      await tester.pump();

      final initialCalls = (cubit! as _RefreshCountingCubit).refreshCallCount;
      expect(initialCalls, 0);

      await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
      await tester.pump();
      await _awaitHistoryRefresh(tester);

      await tester.tap(find.byIcon(PhosphorIconsRegular.sneakerMove));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        (cubit! as _RefreshCountingCubit).refreshCallCount,
        initialCalls + 1,
      );

      await _disposeScaffold(tester);
    });

    testWidgets('AppBottomNav uses floating pill tokens', (
      WidgetTester tester,
    ) async {
      final colors = AstraColors.light();

      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
        ),
        userSettings: deps.userSettings,
      );

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      final pill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == colors.accentPrimary,
          ),
        ).first,
      );
      final pillDecoration = pill.decoration as BoxDecoration;
      expect(pillDecoration.color, colors.accentPrimary);
      expect(
        pillDecoration.borderRadius,
        BorderRadius.circular(AstraSpacing.kRadiusFull),
      );

      final pillBox = tester.getSize(find.byWidget(pill));
      expect(pillBox.height, AstraSpacing.kBottomNavBarHeight);
      final expectedPillWidth =
          AstraSpacing.kBottomNavHorizontalPadding * 2 +
          AstraSpacing.kBottomNavItemSize * 3 +
          AstraSpacing.kBottomNavItemGap * 2;
      expect(pillBox.width, expectedPillWidth);

      void expectClipPathOnSelectedNavTabOnly() {
        final nav = find.byType(AppBottomNav);

        expect(
          find.descendant(of: nav, matching: find.byType(ClipPath)),
          findsOneWidget,
        );

        final selectedNavItem = find.descendant(
          of: nav,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.button == true &&
                w.properties.selected == true,
          ),
        );
        expect(selectedNavItem, findsOneWidget);
        expect(
          find.descendant(of: selectedNavItem, matching: find.byType(ClipPath)),
          findsOneWidget,
        );

        final inactiveNavItems = find.descendant(
          of: nav,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.button == true &&
                w.properties.selected == false,
          ),
        );
        expect(inactiveNavItems, findsNWidgets(2));
        expect(
          find.descendant(of: inactiveNavItems, matching: find.byType(ClipPath)),
          findsNothing,
        );
      }

      expectClipPathOnSelectedNavTabOnly();

      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().contains('SmoothRectangleBorder'),
        ),
        findsNothing,
      );

      await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
      await tester.pump();
      expectClipPathOnSelectedNavTabOnly();

      await tester.tap(find.byIcon(PhosphorIconsRegular.list));
      await tester.pump();
      expectClipPathOnSelectedNavTabOnly();

      await _disposeScaffold(tester);
    });

    Future<void> openMenuTab(WidgetTester tester) async {
      await tester.tap(find.byIcon(PhosphorIconsRegular.list));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }

    testWidgets('Menu pushes Profile with header and pops back to hub', (
      tester,
    ) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
          createHistoryCubit: _testHistoryCubit,
        ),
        userSettings: deps.userSettings,
      );

      await openMenuTab(tester);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text('Profile'), findsWidgets);
      expect(find.text('My Profile'), findsNothing);
      expect(find.text('Informations'), findsWidgets);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Receive Goal notifications'), findsNothing);
      expect(find.textContaining('ASTRA v'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ThemeSelector), findsNothing);
      expect(find.byType(AccentPresetSelector), findsNothing);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.list), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Informations'), findsOneWidget);

      await _disposeScaffold(tester);
    });

    testWidgets('Menu pushes Data with header and pops back to hub', (
      tester,
    ) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
          createHistoryCubit: _testHistoryCubit,
        ),
        userSettings: deps.userSettings,
      );

      await openMenuTab(tester);

      await tester.tap(find.text('Data'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text(l10n.menuData), findsWidgets);
      expect(find.text(l10n.menuPrivacyAndData), findsNothing);
      expect(find.text('My Data'), findsNothing);
      expect(find.text(l10n.menuTrackingStatus), findsOneWidget);
      expect(find.text(l10n.myDataFootprint), findsOneWidget);
      expect(find.text(l10n.myDataYourData), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);

      await _disposeScaffold(tester);
    });

    testWidgets('Menu pushes Settings with Units, Notifications, and Theme cards', (
      tester,
    ) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
          createHistoryCubit: _testHistoryCubit,
        ),
        userSettings: deps.userSettings,
      );

      await openMenuTab(tester);

      await tester.tap(find.widgetWithText(MenuNavRow, 'Settings'));
      await tester.pump();
      var settingsLoaded = false;
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Receive Goal notifications').evaluate().isNotEmpty) {
          settingsLoaded = true;
          break;
        }
      }
      expect(
        settingsLoaded,
        isTrue,
        reason: 'Settings body did not load within 1s after ProfileCubit.refresh',
      );

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Receive Goal notifications'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(ThemeSelector), findsOneWidget);
      expect(find.byType(AccentPresetSelector), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Menu'), findsOneWidget);

      await _disposeScaffold(tester);
    });

    testWidgets('Menu pushes About with header and body content', (tester) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
          createHistoryCubit: _testHistoryCubit,
        ),
        userSettings: deps.userSettings,
      );

      await openMenuTab(tester);

      await tester.tap(find.text('About'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text('About'), findsWidgets);
      expect(find.text('Astra Health'), findsOneWidget);
      expect(find.text('Version: 0.2.2'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Menu'), findsOneWidget);

      await _disposeScaffold(tester);
    });

    testWidgets(
      'postPurgeRefresh failure surfaces purgeErrorMessage on MyDataCubit',
      (tester) async {
        MyDataCubit? myDataCubit;

        await _pumpAppScaffold(
          tester,
          AppScaffold(
            deps: deps,
            createTodayCubit: (dependencies) => _ThrowingRefreshTodayCubit(
              stepAggregation: dependencies.stepAggregation,
              userSettings: dependencies.userSettings,
              userHealthMetrics: dependencies.userHealthMetrics,
              clock: dependencies.timeProvider,
            ),
            createHistoryCubit: _testHistoryCubit,
            onMyDataCubitReady: (cubit) => myDataCubit = cubit,
          ),
          userSettings: deps.userSettings,
        );
        await tester.pump();

        expect(myDataCubit, isNotNull);
        await tester.runAsync(() async {
          await myDataCubit!.refresh();
          await myDataCubit!.confirmAndPurge(
            confirmedAction: PurgeConfirmAction.deleteConfirmed,
          );
        });
        await tester.pump();

        expect(myDataCubit!.state.purgeSuccessPending, isFalse);
        expect(
          myDataCubit!.state.purgeError,
          MyDataPurgeError.refreshFailedAfterPurge,
        );

        await _disposeScaffold(tester);
      },
    );

    testWidgets('postPurgeRefresh success runs all refresh steps', (
      tester,
    ) async {
      _RefreshCountingCubit? todayCubit;
      _RefreshCountingHistoryCubit? historyCubit;
      MyDataCubit? myDataCubit;

      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: (dependencies) {
            todayCubit = _RefreshCountingCubit(
              stepAggregation: dependencies.stepAggregation,
              userSettings: dependencies.userSettings,
              userHealthMetrics: dependencies.userHealthMetrics,
              clock: dependencies.timeProvider,
            );
            return todayCubit!;
          },
          createHistoryCubit: (dependencies) {
            historyCubit = _RefreshCountingHistoryCubit(
              stepAggregation: dependencies.stepAggregation,
              userHealthMetrics: dependencies.userHealthMetrics,
            );
            return historyCubit!;
          },
          onMyDataCubitReady: (cubit) => myDataCubit = cubit,
        ),
        userSettings: deps.userSettings,
      );
      await tester.pump();

      expect(myDataCubit, isNotNull);
      expect(todayCubit, isNotNull);

      await tester.runAsync(() async {
        await todayCubit!.recordLastDisplayedSteps(3500);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(todayCubit!.state.lastDisplayedSteps, 3500);
      expect(todayCubit!.state.lastDisplayedStepsLoaded, isTrue);

      await tester.runAsync(() async {
        await myDataCubit!.refresh();
        await myDataCubit!.confirmAndPurge(
          confirmedAction: PurgeConfirmAction.deleteConfirmed,
        );
      });
      await tester.pump();

      expect(todayCubit!.refreshCallCount, greaterThanOrEqualTo(1));
      expect(todayCubit!.syncStepsCallCount, 1);
      expect(todayCubit!.refreshMetadataCallCount, greaterThanOrEqualTo(1));
      expect(historyCubit!.refreshCallCount, greaterThanOrEqualTo(1));
      expect(myDataCubit!.state.purgeSuccessPending, isTrue);
      expect(myDataCubit!.state.purgeError, isNull);
      expect(todayCubit!.state.lastDisplayedSteps, isNot(3500));
      expect(todayCubit!.state.lastDisplayedSteps, anyOf(isNull, 0));
      expect(todayCubit!.state.lastDisplayedStepsLoaded, isTrue);

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      await _disposeScaffold(tester);
    });
  });
}
