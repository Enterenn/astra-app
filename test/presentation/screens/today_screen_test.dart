import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/calendar_week.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
import 'package:astra_app/presentation/widgets/activity_stats_row.dart';
import 'package:astra_app/presentation/widgets/section_card.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:astra_app/presentation/widgets/goal_celebration.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
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

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('TodayScreen layout', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late StepRepository stepRepository;
    late FakeTimeProvider clock;

    setUp(() async {
      GoalRing.disableStepPersistence = true;
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      GoalRing.disableStepPersistence = false;
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
      final screen = BlocProvider<TodayCubit>.value(
        value: cubit,
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

      expect(find.text("Today's activity"), findsOneWidget);
    });

    testWidgets('does not show greeting or source chip', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 5420,
          goal: 8000,
          displayName: 'Alex',
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.textContaining('Hello,'), findsNothing);
      expect(find.text('Phone sensor'), findsNothing);
    });

    testWidgets('does not show stale banner when data is stale', (tester) async {
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

      expect(find.byType(StatusBanner), findsNothing);
      expect(find.textContaining('Steps may be delayed'), findsNothing);
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

    testWidgets('preview goal count-ups to goal then shows celebration', (
      tester,
    ) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 0,
          goal: 2500,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit, disableAnimations: false);
      await tester.tap(find.text(TodayScreen.kPreviewGoalCelebrationLabel));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.isGoalPreviewActive, isTrue);
      expect(find.byType(GoalRing), findsOneWidget);
      expect(find.byType(GoalCelebration), findsNothing);

      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();

      expect(find.byType(GoalCelebration), findsOneWidget);
      expect(cubit.state.showCelebration, isTrue);
    });

    test('previewCelebration chains into celebration after count-up', () {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 0,
          goal: 2500,
          isStale: false,
          weekDays: sampleWeekDays(),
        ),
      );
      addTearDown(cubit.close);

      cubit.previewCelebration();
      expect(cubit.state.isGoalPreviewActive, isTrue);
      expect(cubit.state.showCelebration, isFalse);

      cubit.completeGoalPreviewCountUp();
      expect(cubit.state.showCelebration, isTrue);
    });

  });
}
