import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:astra_app/presentation/screens/app_scaffold.dart';
import 'package:astra_app/presentation/widgets/app_bottom_nav.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';
import '../../core/time/fake_time_provider.dart';

TodayCubit _testTodayCubit(AppDependencies deps) {
  return TodayCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
    clock: deps.timeProvider,
    activityPermissionGranted: () async => true,
  );
}

HistoryCubit _testHistoryCubit(AppDependencies deps) {
  return HistoryCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
  );
}

class _RefreshCountingCubit extends TodayCubit {
  _RefreshCountingCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.clock,
  }) : super(activityPermissionGranted: () async => true);

  int refreshCallCount = 0;

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCallCount++;
    await super.refresh(silent: silent);
  }

  @override
  Future<void> refreshMetadata() async {
    refreshCallCount++;
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

Future<void> _pumpAppScaffold(
  WidgetTester tester,
  AppScaffold scaffold, {
  bool disableAnimations = true,
  required UserPreferencesRepository userPreferences,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: BlocProvider(
            create: (_) => ThemeCubit(
              userPreferences: userPreferences,
              initialPreference: AstraThemePreference.system,
            ),
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

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AppScaffold', () {
    late Database db;
    late AppDependencies deps;

    setUp(() {
      GoalRing.disableStepPersistence = true;
    });

    tearDown(() {
      GoalRing.disableStepPersistence = false;
    });

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final userPreferences = UserPreferencesRepository(db, clock: clock);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
      );
    });

    tearDownAll(() async {
      await db.close();
    });

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
          userPreferences: deps.userPreferences,
        );

        expect(find.text("Today's activity"), findsOneWidget);
        expect(find.text('Steps'), findsOneWidget);
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
        expect(find.text('Storage on this device'), findsNothing);
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
        userPreferences: deps.userPreferences,
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Steps'), findsOneWidget);

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
              stepRepository: dependencies.stepRepository,
              userPreferences: dependencies.userPreferences,
              clock: dependencies.timeProvider,
            );
            return cubit!;
          },
          createHistoryCubit: _testHistoryCubit,
        ),
        userPreferences: deps.userPreferences,
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
        userPreferences: deps.userPreferences,
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

      await _disposeScaffold(tester);
    });
  });
}
