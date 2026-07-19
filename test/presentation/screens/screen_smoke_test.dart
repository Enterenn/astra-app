@Tags(['critical'])
library;

import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/calendar_week.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/cubits/units_cubit.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/screens/history_screen.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
import 'package:astra_app/presentation/widgets/activity_stats_row.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:astra_app/presentation/widgets/section_card.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:astra_app/presentation/widgets/trends_average_stats_row.dart';
import 'package:astra_app/presentation/widgets/trends_monthly_bar_chart.dart';
import 'package:astra_app/presentation/widgets/trends_peak_day_card.dart';
import 'package:astra_app/presentation/widgets/trend_chip.dart';
import 'package:astra_app/presentation/widgets/week_progress_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/l10n_test_helper.dart';
import '../../helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';

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

class _SeededHistoryCubit extends HistoryCubit {
  _SeededHistoryCubit({
    required super.stepAggregation,
    required super.userHealthMetrics,
    required HistoryState initial,
  }) {
    emit(initial);
  }

  @override
  Future<void> refresh({bool silent = true}) async {}
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('TodayScreen smoke', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late StepAggregationRepository stepAggregation;
    late FakeTimeProvider clock;
    late UnitsCubit unitsCubit;

    setUp(() async {
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepAggregation = StepAggregationRepository(db, clock: clock);
      unitsCubit = UnitsCubit(userSettings: userSettings);
    });

    tearDown(() async {
      await unitsCubit.close();
      await db.close();
    });

    _SeededTodayCubit buildCubit(TodayState state) {
      return _SeededTodayCubit(
        stepAggregation: stepAggregation,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        initial: state,
      );
    }

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

    List<WeekDayStatus> sampleWeekDaysWithTrophyScore() {
      final reference = DateTime.utc(2026, 6, 6);
      return [
        for (final day in CalendarWeek.daysContaining(reference))
          WeekDayStatus(
            localDay: day,
            weekdayLabel: CalendarWeek.weekdayLabelFor(day),
            dayNumber: day.day,
            isToday: day == reference,
            isFuture: day.isAfter(reference),
            goalMet: !day.isAfter(reference) &&
                day.isBefore(reference) &&
                day.weekday <= DateTime.wednesday,
          ),
      ];
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      TodayCubit cubit, {
      bool disableAnimations = true,
    }) async {
      final screen = MultiBlocProvider(
        providers: [
          BlocProvider<TodayCubit>.value(value: cubit),
          BlocProvider<UnitsCubit>.value(value: unitsCubit),
        ],
        child: const TodayScreen(),
      );
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: disableAnimations
              ? MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: screen,
                )
              : screen,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('ready layout: title, week above ring, no greeting, three cards', (
      tester,
    ) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 5420,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

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

      final weekCard = find.ancestor(
        of: find.text('This week'),
        matching: find.byType(SectionCard),
      );
      final ring = find.byType(GoalRing);
      expect(tester.getTopLeft(weekCard).dy, lessThan(tester.getTopLeft(ring).dy));

      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.text('Phone sensor'), findsNothing);

      expect(find.text('Set goal'), findsOneWidget);
      expect(find.byType(ActivityStatsRow), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.byType(WeekProgressRow), findsOneWidget);
      expect(find.byType(SectionCard), findsOneWidget);
    });

    testWidgets(
      'does not crash when weekDays empty during loading',
      (tester) async {
        final cubit = buildCubit(const TodayState.loading());
        addTearDown(cubit.close);

        await pumpScreen(tester, cubit);

        expect(find.byType(GoalRing), findsOneWidget);
      },
    );

    testWidgets('shows stale banner when data is stale', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: true,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.byType(StatusBanner), findsOneWidget);
      expect(find.textContaining(l10n.bannerStaleData), findsOneWidget);
    });

    testWidgets('week card trophy: shows N/7 when loaded, hidden while loading', (
      tester,
    ) async {
      final loaded = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDaysWithTrophyScore(),
        ),
      );
      addTearDown(loaded.close);
      await pumpScreen(tester, loaded);
      expect(find.text('3/7'), findsOneWidget);

      final loading = buildCubit(const TodayState.loading());
      addTearDown(loading.close);
      await pumpScreen(tester, loading);
      expect(find.textContaining('/7'), findsNothing);
    });

    testWidgets('week pills tap updates selected day in cubit', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
          selectedLocalDay: sampleWeekDays().first.localDay,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      final target = sampleWeekDays()[1];
      await tester.tap(find.text('${target.dayNumber}').first);
      await tester.pump();

      expect(
        cubit.state.selectedLocalDay?.year,
        target.localDay.year,
      );
      expect(
        cubit.state.selectedLocalDay?.month,
        target.localDay.month,
      );
      expect(
        cubit.state.selectedLocalDay?.day,
        target.localDay.day,
      );
    });

    testWidgets('future week pill tap does not change selected day', (
      tester,
    ) async {
      final weekDays = sampleWeekDays();
      final today = weekDays.singleWhere((day) => day.isToday);
      final futureDay = weekDays.firstWhere((day) => day.isFuture);
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: weekDays,
          selectedLocalDay: today.localDay,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      await tester.tap(find.text('${futureDay.dayNumber}'));
      await tester.pump();

      expect(cubit.state.selectedLocalDay?.day, today.localDay.day);
    });
  });

  group('HistoryScreen smoke', () {
    late Database db;
    late UserHealthMetricsRepository userHealthMetrics;
    late StepAggregationRepository stepAggregation;

    setUp(() async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepAggregation = StepAggregationRepository(db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpScreen(
      WidgetTester tester,
      HistoryCubit cubit,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: SizedBox(
            height: 640,
            width: 400,
            child: BlocProvider<HistoryCubit>.value(
              value: cubit,
              child: const HistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows Trends screen title with semantics label', (
      tester,
    ) async {
      final cubit = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.empty(),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.text('Trends'), findsOneWidget);
      expect(find.text('History'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HistoryScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Trends',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies bottom nav clearance on outer padding', (
      tester,
    ) async {
      final cubit = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.empty(),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      final expectedBottom =
          AstraSpacing.kBottomNavBottomOffset +
          AstraSpacing.kBottomNavBarHeight +
          AstraSpacing.kSpaceMd;

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(HistoryScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding is EdgeInsets &&
                (widget.padding as EdgeInsets).bottom == expectedBottom,
          ),
        ),
      );

      expect((padding.padding as EdgeInsets).bottom, expectedBottom);
    });

    testWidgets('shows average stat cards when ready with periodAverages', (
      tester,
    ) async {
      final cubit = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          chartPoints: [
            ChartDayAggregate(
              localDay: DateTime.utc(2026, 6, 3),
              totalSteps: 5000,
            ),
          ],
          dailyGoal: 8000,
          periodAverages: const TrendsPeriodAverages(
            averageKcal: 167,
            averageSteps: 3532,
          ),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.byType(TrendsAverageStatsRow), findsOneWidget);
      expect(
        find.text('average calories burned per day'),
        findsOneWidget,
      );
      expect(find.text('average steps taken per day'), findsOneWidget);
    });

    testWidgets('hides average stat cards on empty, loading, and null periodAverages', (
      tester,
    ) async {
      final empty = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.empty(),
      );
      addTearDown(empty.close);
      await pumpScreen(tester, empty);
      expect(find.byType(TrendsAverageStatsRow), findsNothing);

      final loading = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: const HistoryState.loading(),
      );
      addTearDown(loading.close);
      await pumpScreen(tester, loading);
      expect(find.byType(TrendsAverageStatsRow), findsNothing);

      final nullAverages = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          chartPoints: List.generate(
            7,
            (i) => ChartDayAggregate(
              localDay: DateTime.utc(2026, 6, 3 - i),
              totalSteps: 0,
            ),
          ),
          dailyGoal: 8000,
        ),
      );
      addTearDown(nullAverages.close);
      await pumpScreen(tester, nullAverages);
      expect(find.byType(TrendsAverageStatsRow), findsNothing);
    });

    testWidgets('shows peak day card when ready with peakDay', (tester) async {
      final cubit = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          chartPoints: [
            ChartDayAggregate(
              localDay: DateTime.utc(2026, 6, 3),
              totalSteps: 8500,
            ),
          ],
          dailyGoal: 8000,
          periodAverages: const TrendsPeriodAverages(
            averageKcal: 167,
            averageSteps: 3532,
          ),
          peakDay: TrendsPeakDay(
            localDay: DateTime.utc(2026, 6, 4),
            totalSteps: 8500,
          ),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.byType(TrendsPeakDayCard), findsOneWidget);
      expect(find.text(l10n.trendsPeakDayCaption), findsOneWidget);
      expect(find.text('8500'), findsOneWidget);
    });

    testWidgets('hides peak day card on loading, null periodAverages, and null peakDay', (
      tester,
    ) async {
      final loading = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: const HistoryState.loading(),
      );
      addTearDown(loading.close);
      await pumpScreen(tester, loading);
      expect(find.byType(TrendsPeakDayCard), findsNothing);

      final nullAverages = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          chartPoints: List.generate(
            7,
            (i) => ChartDayAggregate(
              localDay: DateTime.utc(2026, 6, 3 - i),
              totalSteps: 0,
            ),
          ),
          dailyGoal: 8000,
        ),
      );
      addTearDown(nullAverages.close);
      await pumpScreen(tester, nullAverages);
      expect(find.byType(TrendsPeakDayCard), findsNothing);

      final nullPeak = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          chartPoints: [
            ChartDayAggregate(
              localDay: DateTime.utc(2026, 6, 3),
              totalSteps: 5000,
            ),
          ],
          dailyGoal: 8000,
          periodAverages: const TrendsPeriodAverages(
            averageKcal: 167,
            averageSteps: 3532,
          ),
        ),
      );
      addTearDown(nullPeak.close);
      await pumpScreen(tester, nullPeak);
      expect(find.byType(TrendsPeakDayCard), findsNothing);
    });

    testWidgets('12 months mode shows monthly chart and hides stats', (
      tester,
    ) async {
      final monthlyPoints = List.generate(
        12,
        (i) => ChartMonthAggregate(
          monthStart: DateTime.utc(2025, 7 + i, 1),
          averageDailySteps: 2500,
          totalSteps: 75_000,
          dayCount: 30,
        ),
      );
      final cubit = _SeededHistoryCubit(
        stepAggregation: stepAggregation,
        userHealthMetrics: userHealthMetrics,
        initial: HistoryState.ready(
          period: HistoryPeriod.months12,
          chartPoints: const [],
          monthlyChartPoints: monthlyPoints,
          dailyGoal: 8000,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.byType(TrendsMonthlyBarChart), findsOneWidget);
      expect(find.byType(TrendsAverageStatsRow), findsNothing);
      expect(find.byType(TrendsPeakDayCard), findsNothing);
      expect(find.text('12 months'), findsOneWidget);
      expect(find.text('Jul 2025 – Jun 2026'), findsOneWidget);
      expect(find.byType(CaptionPill), findsOneWidget);
    });
  });
}
