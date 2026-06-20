import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/core/time/calendar_week.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/cubits/units_cubit.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
import 'package:astra_app/presentation/widgets/elevated_card.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/astra_theme_test_helper.dart';
import '../../helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';

Color? goalRingLoadingSkeletonPrimaryBarColor(WidgetTester tester) {
  final skeleton = find.byKey(const Key('goal_ring_loading_skeleton'));
  expect(skeleton, findsOneWidget);
  final containers = tester.widgetList<Container>(
    find.descendant(
      of: skeleton,
      matching: find.byType(Container),
    ),
  );
  expect(containers.length, greaterThanOrEqualTo(1));
  final decoration = containers.first.decoration;
  expect(decoration, isA<BoxDecoration>());
  return (decoration! as BoxDecoration).color;
}

class _SeededTodayCubit extends TodayCubit {
  _SeededTodayCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required TodayState initial,
  }) : super(activityPermissionGranted: () async => true) {
    emit(_displayReady(initial));
  }

  static TodayState _displayReady(TodayState state) {
    if (state.lastDisplayedStepsLoaded ||
        state.status == TodayStatus.loading ||
        state.status == TodayStatus.noPermission) {
      return state;
    }
    return state.copyWith(
      lastDisplayedSteps: state.steps,
      lastDisplayedStepsLoaded: true,
    );
  }

  @override
  Future<void> refresh({bool silent = true}) async {}
}

class _TrackingRefreshCubit extends _SeededTodayCubit {
  _TrackingRefreshCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.initial,
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Future<void> refresh({bool silent = true}) async {
    onRefresh();
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('Today selector slice equality', () {
    List<WeekDayStatus> sampleWeekDays() {
      final reference = DateTime.utc(2026, 6, 3);
      return [
        for (final day in CalendarWeek.daysContaining(reference))
          WeekDayStatus(
            localDay: day,
            weekdayLabel: CalendarWeek.weekdayLabelFor(day),
            dayNumber: day.day,
            isToday: day == reference,
            isFuture: day.isAfter(reference),
            goalMet: false,
          ),
      ];
    }

    test('week slice unchanged when only steps and metrics tick', () {
      final weekDays = sampleWeekDays();
      final before = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: false,
        weekDays: weekDays,
      );
      final after = before.copyWith(
        steps: 1201,
        activityMetrics: const ActivityMetricsSnapshot(
          distanceKm: 0.91,
          walkingDuration: Duration(minutes: 12),
          kcal: 49,
        ),
      );

      expect(todayWeekSliceEquals(before, after), isTrue);
      expect(todayGoalRingSliceEquals(before, after), isFalse);
    });

    test('week slice changes when today goalMet toggles with new list', () {
      final weekDays = sampleWeekDays();
      final before = TodayState.fromData(
        steps: 7999,
        goal: 8000,
        isStale: false,
        weekDays: weekDays,
      );
      final patchedDays = [
        for (final day in weekDays)
          day.isToday
              ? WeekDayStatus(
                  localDay: day.localDay,
                  weekdayLabel: day.weekdayLabel,
                  dayNumber: day.dayNumber,
                  isToday: day.isToday,
                  isFuture: day.isFuture,
                  goalMet: true,
                )
              : day,
      ];
      final after = before.copyWith(
        steps: 8000,
        status: TodayStatus.goalMet,
        weekDays: patchedDays,
      );

      expect(todayWeekSliceEquals(before, after), isFalse);
    });

    test('health slice unchanged when only steps and metrics tick', () {
      final before = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: false,
        lastIngestionUtc: DateTime.utc(2026, 6, 3, 10),
      );
      final after = before.copyWith(
        steps: 1201,
        activityMetrics: const ActivityMetricsSnapshot(
          distanceKm: 0.91,
          walkingDuration: Duration(minutes: 12),
          kcal: 49,
        ),
      );

      expect(todayHealthSliceEquals(before, after), isTrue);
    });

    test('health slice changes when stale flag toggles', () {
      final before = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: false,
      );
      final after = before.copyWith(isStale: true);

      expect(todayHealthSliceEquals(before, after), isFalse);
    });

    test('health slice changes when status becomes loading', () {
      final before = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: false,
      );
      final after = before.copyWith(status: TodayStatus.loading);

      expect(todayHealthSliceEquals(before, after), isFalse);
    });

    test('stale banner hidden when permission denied even if stale', () {
      final state = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: true,
      ).copyWith(status: TodayStatus.noPermission);

      expect(todayStaleBannerVisible(state), isFalse);
    });

    test('stale banner hidden when loading even if stale flag set', () {
      final state = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: true,
      ).copyWith(status: TodayStatus.loading);

      expect(todayStaleBannerVisible(state), isFalse);
    });

    test('stale banner visible when stale and permission granted', () {
      final state = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: true,
      );

      expect(todayStaleBannerVisible(state), isTrue);
    });

    test('activity stats slice changes when only steps and metrics tick', () {
      final before = TodayState.fromData(
        steps: 1200,
        goal: 8000,
        isStale: false,
      );
      final after = before.copyWith(
        steps: 1201,
        activityMetrics: const ActivityMetricsSnapshot(
          distanceKm: 0.91,
          walkingDuration: Duration(minutes: 12),
          kcal: 49,
        ),
      );

      expect(
        todayActivityStatsSelectorSlice(before) ==
            todayActivityStatsSelectorSlice(after),
        isFalse,
      );
    });
  });

  group('TodayScreen BlocSelector build isolation', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late StepAggregationRepository stepAggregation;
    late FakeTimeProvider clock;
    late UnitsCubit unitsCubit;
    final buildCounts = <String, int>{};

    setUp(() async {
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final session = AstraDatabaseSession(
        databasePath: db.path,
        initial: db,
      );
      userSettings = UserSettingsRepository(session);
      userHealthMetrics = UserHealthMetricsRepository(session, clock: clock);
      stepAggregation = StepAggregationRepository(db, clock: clock);
      unitsCubit = UnitsCubit(userSettings: userSettings);
      buildCounts.clear();
      todaySectionBuildProbe = (section) {
        buildCounts[section] = (buildCounts[section] ?? 0) + 1;
      };
    });

    tearDown(() async {
      todaySectionBuildProbe = null;
      await unitsCubit.close();
      await db.close();
    });

    List<WeekDayStatus> sampleWeekDays() {
      final reference = DateTime.utc(2026, 6, 3);
      return [
        for (final day in CalendarWeek.daysContaining(reference))
          WeekDayStatus(
            localDay: day,
            weekdayLabel: CalendarWeek.weekdayLabelFor(day),
            dayNumber: day.day,
            isToday: day == reference,
            isFuture: day.isAfter(reference),
            goalMet: false,
          ),
      ];
    }

    _SeededTodayCubit buildCubit(TodayState state) {
      return _SeededTodayCubit(
        stepAggregation: stepAggregation,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        initial: state,
      );
    }

    Future<_SeededTodayCubit> pumpHealthSlot(
      WidgetTester tester, {
      required TodayState initial,
    }) async {
      final cubit = buildCubit(initial);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TodayCubit>.value(
              value: cubit,
              child: buildTodayHealthSlotForTest(),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    Future<_SeededTodayCubit> pumpStaleBannerSlot(
      WidgetTester tester, {
      required TodayState initial,
    }) async {
      final cubit = buildCubit(initial);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TodayCubit>.value(
              value: cubit,
              child: buildTodayStaleBannerSlotForTest(),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    Future<_SeededTodayCubit> pumpWeekSection(
      WidgetTester tester, {
      required TodayState initial,
    }) async {
      final cubit = buildCubit(initial);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TodayCubit>.value(
              value: cubit,
              child: buildTodayWeekSectionForTest(),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    Future<_SeededTodayCubit> pumpActivityStatsSection(
      WidgetTester tester, {
      required TodayState initial,
    }) async {
      final cubit = buildCubit(initial);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<TodayCubit>.value(value: cubit),
                BlocProvider<UnitsCubit>.value(value: unitsCubit),
              ],
              child: buildTodayActivityStatsSectionForTest(),
            ),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('activity stats selector rebuilds on live metrics emit', (
      tester,
    ) async {
      var builds = 0;
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          activityMetrics: const ActivityMetricsSnapshot(
            distanceKm: 0.9,
            walkingDuration: Duration(minutes: 12),
            kcal: 48,
          ),
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<TodayCubit>.value(value: cubit),
                BlocProvider<UnitsCubit>.value(value: unitsCubit),
              ],
              child: BlocSelector<TodayCubit, TodayState, Object>(
                selector: todayActivityStatsSelectorSlice,
                builder: (context, slice) {
                  builds++;
                  todaySectionBuildProbe?.call('activityStats');
                  return ElevatedCard(
                    child: buildActivityStatsRowForSelectorSlice(slice),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(builds, 1);

      cubit.emit(
        cubit.state.copyWith(
          steps: 1201,
          activityMetrics: const ActivityMetricsSnapshot(
            distanceKm: 0.91,
            walkingDuration: Duration(minutes: 12),
            kcal: 49,
          ),
        ),
      );
      await tester.pump();
      expect(builds, 2);
      expect(buildCounts['activityStats'], 2);
      expect(find.text('49'), findsOneWidget);
    });

    testWidgets('production activity stats section probe rebuilds on emit', (
      tester,
    ) async {
      const initialSteps = 1200;
      final cubit = await pumpActivityStatsSection(
        tester,
        initial: TodayState.fromData(
          steps: initialSteps,
          goal: 8000,
          isStale: false,
          activityMetrics: const ActivityMetricsSnapshot(
            distanceKm: 0.9,
            walkingDuration: Duration(minutes: 12),
            kcal: 48,
          ),
        ),
      );

      final activityBuilds = buildCounts['activityStats'] ?? 0;
      expect(activityBuilds, greaterThan(0));
      expect(find.text('48'), findsOneWidget);

      cubit.emit(
        cubit.state.copyWith(
          steps: initialSteps + 1,
          activityMetrics: const ActivityMetricsSnapshot(
            distanceKm: 0.91,
            walkingDuration: Duration(minutes: 12),
            kcal: 49,
          ),
        ),
      );
      await tester.pump();

      expect(buildCounts['activityStats'], greaterThan(activityBuilds));
      expect(find.text('49'), findsOneWidget);
    });

    testWidgets('GoalRing view-model selector rebuilds on step emit', (
      tester,
    ) async {
      var builds = 0;
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TodayCubit>.value(
            value: cubit,
            child: BlocSelector<TodayCubit, TodayState, Object>(
              selector: todayGoalRingSelectorSlice,
              builder: (context, slice) {
                builds++;
                return Text('$slice');
              },
            ),
          ),
        ),
      );
      expect(builds, 1);

      cubit.emit(cubit.state.copyWith(steps: 1201));
      await tester.pump();
      expect(builds, 2);
    });

    testWidgets('live step tick does not rebuild health selector', (tester) async {
      const initialSteps = 1200;
      final cubit = await pumpHealthSlot(
        tester,
        initial: TodayState.fromData(
          steps: initialSteps,
          goal: 8000,
          isStale: false,
          lastIngestionUtc: DateTime.utc(2026, 6, 3, 10),
        ),
      );

      final healthBuildsAfterPump = buildCounts['health'] ?? 0;
      expect(healthBuildsAfterPump, greaterThan(0));

      final before = cubit.state;
      final nextState = before.copyWith(steps: initialSteps + 1);
      expect(todayHealthSliceEquals(before, nextState), isTrue);

      cubit.emit(nextState);
      await tester.pump();

      expect(buildCounts['health'], healthBuildsAfterPump);
    });

    testWidgets('health slot hidden during loading state', (tester) async {
      await pumpHealthSlot(
        tester,
        initial: TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
        ).copyWith(status: TodayStatus.loading),
      );

      expect(find.text('Collection active ●'), findsNothing);
      expect(find.text('Sensor access revoked ✕'), findsNothing);
    });

    testWidgets('live step tick does not rebuild stale banner selector', (
      tester,
    ) async {
      const initialSteps = 1200;
      final cubit = await pumpStaleBannerSlot(
        tester,
        initial: TodayState.fromData(
          steps: initialSteps,
          goal: 8000,
          isStale: true,
          weekDays: sampleWeekDays(),
        ),
      );

      final staleBannerBuildsAfterPump = buildCounts['staleBanner'] ?? 0;
      expect(staleBannerBuildsAfterPump, greaterThan(0));

      cubit.emit(cubit.state.copyWith(steps: initialSteps + 1));
      await tester.pump();

      expect(buildCounts['staleBanner'], staleBannerBuildsAfterPump);
    });

    testWidgets('stale banner hidden when permission denied', (tester) async {
      await pumpStaleBannerSlot(
        tester,
        initial: TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: true,
        ).copyWith(status: TodayStatus.noPermission),
      );

      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('stale banner hidden during loading state', (tester) async {
      await pumpStaleBannerSlot(
        tester,
        initial: TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: true,
        ).copyWith(status: TodayStatus.loading),
      );

      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('stale banner tap invokes cubit refresh', (tester) async {
      var refreshCalls = 0;
      final cubit = _TrackingRefreshCubit(
        stepAggregation: stepAggregation,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        initial: TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: true,
        ),
        onRefresh: () => refreshCalls++,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TodayCubit>.value(
              value: cubit,
              child: buildTodayStaleBannerSlotForTest(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(StatusBanner));
      await tester.pump();

      expect(refreshCalls, 1);
    });

    testWidgets('live step tick does not rebuild week selector', (tester) async {
      const initialSteps = 1200;
      final cubit = await pumpWeekSection(
        tester,
        initial: TodayState.fromData(
          steps: initialSteps,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );

      final weekBuildsAfterPump = buildCounts['week'] ?? 0;
      expect(weekBuildsAfterPump, greaterThan(0));

      final before = cubit.state;
      final nextState = before.copyWith(steps: initialSteps + 1);
      expect(todayWeekSliceEquals(before, nextState), isTrue);

      cubit.emit(nextState);
      await tester.pump();

      expect(buildCounts['week'], weekBuildsAfterPump);
    });

    testWidgets('week selector rebuilds when week slice changes', (tester) async {
      var builds = 0;
      final weekDays = sampleWeekDays();
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 7999,
          goal: 8000,
          isStale: false,
          weekDays: weekDays,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TodayCubit>.value(
            value: cubit,
            child: BlocSelector<TodayCubit, TodayState, Object>(
              selector: todayWeekSelectorSlice,
              builder: (context, slice) {
                builds++;
                return Text('$slice');
              },
            ),
          ),
        ),
      );
      expect(builds, 1);

      final patchedDays = [
        for (final day in weekDays)
          day.isToday
              ? WeekDayStatus(
                  localDay: day.localDay,
                  weekdayLabel: day.weekdayLabel,
                  dayNumber: day.dayNumber,
                  isToday: day.isToday,
                  isFuture: day.isFuture,
                  goalMet: true,
                )
              : day,
      ];
      cubit.emit(
        cubit.state.copyWith(
          steps: 8000,
          status: TodayStatus.goalMet,
          weekDays: patchedDays,
        ),
      );
      await tester.pump();
      expect(builds, 2);
    });

    testWidgets(
      'full TodayScreen live tick rebuilds activity stats but not static shell or week',
      (tester) async {
        const initialSteps = 1200;
        final cubit = buildCubit(
          TodayState.fromData(
            steps: initialSteps,
            goal: 8000,
            isStale: false,
            weekDays: sampleWeekDays(),
            activityMetrics: const ActivityMetricsSnapshot(
              distanceKm: 0.9,
              walkingDuration: Duration(minutes: 12),
              kcal: 48,
            ),
          ),
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAstraLightTheme(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<TodayCubit>.value(value: cubit),
                  BlocProvider<UnitsCubit>.value(value: unitsCubit),
                ],
                child: const TodayScreen(),
              ),
            ),
          ),
        );
        final titleBuilds = buildCounts['staticTitle'] ?? 0;
        final setGoalBuilds = buildCounts['staticSetGoal'] ?? 0;
        final weekBuilds = buildCounts['week'] ?? 0;
        final healthBuilds = buildCounts['health'] ?? 0;
        final staleBannerBuilds = buildCounts['staleBanner'] ?? 0;
        final activityBuilds = buildCounts['activityStats'] ?? 0;

        expect(titleBuilds, greaterThan(0));
        expect(setGoalBuilds, greaterThan(0));
        expect(weekBuilds, greaterThan(0));
        expect(healthBuilds, greaterThan(0));
        expect(activityBuilds, greaterThan(0));
        expect(find.text('48'), findsOneWidget);

        final beforeStatsSlice = todayActivityStatsSelectorSlice(cubit.state);
        final nextMetrics = const ActivityMetricsSnapshot(
          distanceKm: 0.91,
          walkingDuration: Duration(minutes: 12),
          kcal: 49,
        );
        cubit.emit(
          cubit.state.copyWith(
            steps: initialSteps + 1,
            activityMetrics: nextMetrics,
          ),
        );
        expect(
          todayActivityStatsSelectorSlice(cubit.state) == beforeStatsSlice,
          isFalse,
        );
        await tester.pump();

        expect(buildCounts['staticTitle'], titleBuilds);
        expect(buildCounts['staticSetGoal'], setGoalBuilds);
        expect(buildCounts['week'], weekBuilds);
        expect(buildCounts['health'], healthBuilds);
        expect(buildCounts['staleBanner'], staleBannerBuilds);
        expect(buildCounts['activityStats'], greaterThan(activityBuilds));
        expect(find.text('49'), findsOneWidget);
      },
    );
  });

  group('GoalRing loading skeleton reduce motion', () {
    testWidgets(
      'static center skeleton when OS reduce motion is enabled (AC #4)',
      (tester) async {
        await tester.pumpWidget(
          wrapWithAstraTheme(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Center(
                child: SizedBox(
                  width: 400,
                  child: GoalRing(state: const TodayState.loading()),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('goal_ring_loading_skeleton')),
          findsOneWidget,
        );
        expect(find.textContaining('/'), findsNothing);

        // No ring pulse layer — pulseController stays null when reduce motion is on.
        expect(
          find.descendant(
            of: find.byType(GoalRing),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );

        final colorBefore = goalRingLoadingSkeletonPrimaryBarColor(tester);
        expect(colorBefore, isNotNull);

        await tester.pump(const Duration(seconds: 2));
        await tester.pump();

        expect(goalRingLoadingSkeletonPrimaryBarColor(tester), colorBefore);
      },
    );
  });
}
