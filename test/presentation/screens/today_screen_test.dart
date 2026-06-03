import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
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

  group('TodayScreen greeting', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late StepRepository stepRepository;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      stepRepository = StepRepository(
        db: db,
        clock: FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
          zoneOffset: const Duration(hours: 2),
        ),
      );
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
    });

    tearDown(() async {
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

    Future<void> pumpScreen(WidgetTester tester, TodayCubit cubit) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: BlocProvider<TodayCubit>.value(
            value: cubit,
            child: TodayScreen(onNavigateToMyData: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows Hello caption when display name is set', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          displayName: 'Alex',
          isStale: false,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.text('Hello, Alex'), findsOneWidget);
    });

    testWidgets('hides greeting when display name is absent', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 1200,
          goal: 8000,
          isStale: false,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.textContaining('Hello,'), findsNothing);
    });

    testWidgets('does not show step total in greeting line', (tester) async {
      final cubit = buildCubit(
        TodayState.fromData(
          steps: 5420,
          goal: 8000,
          displayName: 'Alex',
          isStale: false,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.text('Hello, Alex'), findsOneWidget);
      expect(find.text('Hello, 5420'), findsNothing);
    });
  });
}
