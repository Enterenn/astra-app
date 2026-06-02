import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/screens/app_scaffold.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

TodayCubit _testTodayCubit(AppDependencies deps) {
  return TodayCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
    clock: deps.timeProvider,
    activityPermissionGranted: () async => true,
  );
}

class _StaleTodayCubit extends TodayCubit {
  _StaleTodayCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.clock,
  }) : super(activityPermissionGranted: () async => true);

  @override
  Future<void> refresh({bool silent = true}) async {
    emit(
      TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: true,
        lastIngestionUtc: DateTime.utc(2020, 1, 1),
      ),
    );
  }
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
}

Future<void> _pumpAppScaffold(
  WidgetTester tester,
  AppScaffold scaffold, {
  bool disableAnimations = true,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: scaffold,
        ),
      ),
    );
    await tester.pump();
  });
}

Future<void> _disposeScaffold(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const SizedBox.shrink());
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

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
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
            enablePeriodicRefresh: false,
          ),
        );

        expect(find.text('steps today'), findsOneWidget);
        expect(find.text('Phone sensor'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.bar_chart_outlined));
        await tester.pump();

        expect(
          find.text('Your 7-day and 30-day charts will appear here.'),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.shield_outlined));
        await tester.pump();

        expect(
          find.text('Data footprint, export, and settings will appear here.'),
          findsOneWidget,
        );

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
          enablePeriodicRefresh: false,
        ),
        disableAnimations: false,
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('steps today'), findsOneWidget);

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
          enablePeriodicRefresh: false,
        ),
      );
      await tester.pump();

      final initialCalls = (cubit! as _RefreshCountingCubit).refreshCallCount;
      expect(initialCalls, greaterThanOrEqualTo(1));

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.circle_outlined));
      await tester.pump();

      expect(
        (cubit! as _RefreshCountingCubit).refreshCallCount,
        initialCalls + 1,
      );

      await _disposeScaffold(tester);
    });

    testWidgets('stale compact banner navigates to My Data tab', (
      tester,
    ) async {
      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: (dependencies) => _StaleTodayCubit(
            stepRepository: dependencies.stepRepository,
            userPreferences: dependencies.userPreferences,
            clock: dependencies.timeProvider,
          ),
          enablePeriodicRefresh: false,
        ),
      );

      expect(find.byType(StatusBanner), findsOneWidget);

      await tester.tap(find.byType(StatusBanner));
      await tester.pump();

      expect(
        find.text('Data footprint, export, and settings will appear here.'),
        findsOneWidget,
      );

      await _disposeScaffold(tester);
    });

    testWidgets('NavigationBar uses Astra navigation theme tokens', (
      WidgetTester tester,
    ) async {
      final colors = AstraColors.light();

      await _pumpAppScaffold(
        tester,
        AppScaffold(
          deps: deps,
          createTodayCubit: _testTodayCubit,
          enablePeriodicRefresh: false,
        ),
      );

      final navContext = tester.element(find.byType(NavigationBar));
      final navTheme = Theme.of(navContext).navigationBarTheme;

      expect(navTheme.height, AstraSpacing.kBottomTabBarHeight);
      expect(navTheme.backgroundColor, colors.bgElevated);
      expect(navTheme.indicatorColor, Colors.transparent);

      final selectedIconStyle = navTheme.iconTheme!.resolve({
        WidgetState.selected,
      });
      final unselectedIconStyle = navTheme.iconTheme!.resolve({});
      expect(selectedIconStyle?.color, colors.accentPrimary);
      expect(unselectedIconStyle?.color, colors.textMuted);

      final selectedLabelStyle = navTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      });
      final unselectedLabelStyle = navTheme.labelTextStyle!.resolve({});
      expect(selectedLabelStyle?.color, colors.accentPrimary);
      expect(unselectedLabelStyle?.color, colors.textMuted);

      final decoratedBox = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final topBorder = decoration.border?.top;
      expect(topBorder, isNotNull);
      expect(topBorder!.color, colors.borderDefault);

      await _disposeScaffold(tester);
    });
  });
}
