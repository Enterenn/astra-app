import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

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

  group('HistoryScreen', () {
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
