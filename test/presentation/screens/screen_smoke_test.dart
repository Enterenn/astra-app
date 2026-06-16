import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/calendar_week.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
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
import 'package:astra_app/presentation/widgets/week_progress_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _SeededTodayCubit extends TodayCubit {
  _SeededTodayCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.clock,
    required TodayState initial,
  }) : super(activityPermissionGranted: () async => true) {
    emit(initial);
  }

  @override
  Future<void> refresh({bool silent = true}) async {}
}

class _SeededHistoryCubit extends HistoryCubit {
  _SeededHistoryCubit({
    required super.stepRepository,
    required super.userPreferences,
    required HistoryState initial,
  }) {
    emit(initial);
  }

  @override
  Future<void> refresh({bool silent = true}) async {}
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('TodayScreen smoke', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late StepRepository stepRepository;
    late FakeTimeProvider clock;
    late UnitsCubit unitsCubit;

    setUp(() async {
      GoalRing.disableStepPersistence = true;
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      stepRepository = StepRepository(db: db, clock: clock);
      unitsCubit = UnitsCubit(userPreferences: userPreferences);
    });

    tearDown(() async {
      GoalRing.disableStepPersistence = false;
      await unitsCubit.close();
      await db.close();
    });

    _SeededTodayCubit buildCubit(TodayState state) {
      return _SeededTodayCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
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
        MaterialApp(
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

    testWidgets('shows screen title', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
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

    testWidgets('week card appears above goal ring', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      final weekCard = find.ancestor(
        of: find.text('This week'),
        matching: find.byType(SectionCard),
      );
      final ring = find.byType(GoalRing);
      expect(tester.getTopLeft(weekCard).dy, lessThan(tester.getTopLeft(ring).dy));
    });

    testWidgets('does not show greeting or source chip', (tester) async {
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

      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.text('Phone sensor'), findsNothing);
    });

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
      expect(find.textContaining('Steps may be delayed'), findsOneWidget);
    });

    testWidgets('shows three main cards', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.text('Set goal'), findsOneWidget);
      expect(find.byType(ActivityStatsRow), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.byType(WeekProgressRow), findsOneWidget);
      expect(find.byType(SectionCard), findsOneWidget);
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
    late UserPreferencesRepository userPreferences;
    late StepRepository stepRepository;

    setUp(() async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpScreen(
      WidgetTester tester,
      HistoryCubit cubit,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
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
        stepRepository: stepRepository,
        userPreferences: userPreferences,
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
        stepRepository: stepRepository,
        userPreferences: userPreferences,
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
  });
}
