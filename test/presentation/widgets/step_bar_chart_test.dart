import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_core.dart';
import 'package:astra_app/presentation/widgets/chart/chart_axis_ticks.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bar_chart_touch_test_helper.dart';
import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('StepBarChart', () {
    Future<void> pumpChart(
      WidgetTester tester, {
      required HistoryStatus status,
      List<ChartDayAggregate> points = const [],
      int dailyGoal = 8000,
      Map<String, int> goalsByDay = const {},
      double width = 320,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: StepBarChart.kDailyChartHeight,
              child: StepBarChart(
                points: points,
                dailyGoal: dailyGoal,
                goalsByDay: goalsByDay,
                status: status,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('empty state shows exact copy', (tester) async {
      await pumpChart(tester, status: HistoryStatus.empty);

      expect(find.text(l10n.trendsEmptyHistory), findsOneWidget);
    });

    testWidgets('loading state shows seven skeleton bars', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: SizedBox(
              height: StepBarChart.kDailyChartHeight,
              child: StepBarChart(
                points: [],
                dailyGoal: 8000,
                goalsByDay: {},
                status: HistoryStatus.loading,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final skeletonBars = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is! BoxDecoration) {
          return false;
        }
        final radius = decoration.borderRadius;
        return radius is BorderRadius &&
            radius.topLeft == const Radius.circular(4);
      });
      expect(skeletonBars.length, 7);
    });

    testWidgets('semantics label is present when chart is ready', (tester) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 5000,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
      );

      final semantics = tester.getSemantics(
        find.descendant(
          of: find.byType(StepBarChart),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Step history bar chart',
          ),
        ),
      );
      expect(semantics.label, 'Step history bar chart');
    });

    testWidgets('ready state builds native chart without throw', (tester) async {
      final points = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 1000 + i * 100,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AstraBarChartCore), findsOneWidget);
    });

    testWidgets('ready 7d shows each weekday label once', (tester) async {
      final points = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 1000 + i * 100,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
      );

      for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('ready 30d throttles date labels without duplicates', (
      tester,
    ) async {
      final points = [
        for (var i = 0; i < 30; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 3 + i),
            totalSteps: 500 + i * 50,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 8000,
      );

      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('8/5'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);
    });

    testWidgets('shows single goal line when all visible goals are equal', (
      tester,
    ) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 8),
          totalSteps: 9000,
        ),
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 5000,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 10000,
        goalsByDay: const {
          '2026-06-08': 8000,
          '2026-06-09': 8000,
        },
      );

      expect(hasSingleGoalLinePainter(tester), isTrue);
      expect(hasGoalStepLinePainter(tester), isFalse);
    });

    testWidgets('shows stepped goal overlay when visible goals differ', (
      tester,
    ) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 8),
          totalSteps: 9000,
        ),
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 5000,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 10000,
        goalsByDay: const {
          '2026-06-08': 8000,
          '2026-06-09': 10000,
        },
      );

      expect(hasSingleGoalLinePainter(tester), isFalse);
      expect(hasGoalStepLinePainter(tester), isTrue);
    });

    testWidgets('colors bars against per-day resolved goals', (tester) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 8),
          totalSteps: 8500,
        ),
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 5000,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 10000,
        goalsByDay: const {
          '2026-06-08': 8000,
          '2026-06-09': 10000,
        },
      );

      final colors = barColorsFromChart(tester);
      expect(colors.length, 2);
      expect(colors.first, isNot(equals(colors.last)));
    });

    testWidgets('ready chart renders at least four Y-axis tick labels', (
      tester,
    ) async {
      final points = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 6000 + i * 700,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 8000,
        goalsByDay: const {
          '2026-05-26': 8000,
          '2026-05-27': 8000,
          '2026-05-28': 8000,
          '2026-05-29': 8000,
          '2026-05-30': 8000,
          '2026-05-31': 8000,
          '2026-06-01': 8000,
        },
      );

      final core = tester.widget<AstraBarChartCore>(
        find.byType(AstraBarChartCore),
      );
      final ticks = computeChartYAxisTicks(
        maxY: core.maxY,
        referenceValues: const [8000],
      );

      var renderedCount = 0;
      for (final tick in ticks) {
        final label = formatChartAxisValue(tick.round());
        if (find.text(label).evaluate().isNotEmpty) {
          renderedCount++;
        }
      }

      expect(renderedCount, greaterThanOrEqualTo(4));
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('ready chart computes at least four Y-axis ticks', (
      tester,
    ) async {
      final points = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 6000 + i * 700,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 8000,
        goalsByDay: const {
          '2026-05-26': 8000,
          '2026-05-27': 8000,
          '2026-05-28': 8000,
          '2026-05-29': 8000,
          '2026-05-30': 8000,
          '2026-05-31': 8000,
          '2026-06-01': 8000,
        },
      );

      final chartMaxY = tester
          .widget<AstraBarChartCore>(find.byType(AstraBarChartCore))
          .maxY;
      final ticks = computeChartYAxisTicks(
        maxY: chartMaxY,
        referenceValues: const [8000],
      );

      expect(ticks.length, greaterThanOrEqualTo(4));
      expect(ticks, contains(0));
      expect(ticks.last, chartMaxY);
    });

    testWidgets('bar touch selects bar and shows tooltip', (tester) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 8547,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 8000,
        goalsByDay: const {'2026-06-09': 8000},
      );

      final core = tester.widget<AstraBarChartCore>(
        find.byType(AstraBarChartCore),
      );
      await tapBarAtIndex(
        tester,
        barIndex: 0,
        barCount: 1,
        barWidth: core.barWidth,
        plotWidth: 320 - 36 - 16,
      );

      expect(find.text('9 June\n8547/8000 steps'), findsOneWidget);
    });

    testWidgets('selected bar updates semantics summary', (tester) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 9),
          totalSteps: 8547,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
        dailyGoal: 8000,
        goalsByDay: const {'2026-06-09': 8000},
      );

      final core = tester.widget<AstraBarChartCore>(
        find.byType(AstraBarChartCore),
      );
      await tapBarAtIndex(
        tester,
        barIndex: 0,
        barCount: 1,
        barWidth: core.barWidth,
        plotWidth: 320 - 36 - 16,
      );

      final semantics = tester.getSemantics(
        find.descendant(
          of: find.byType(StepBarChart),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.contains('9 June, 8547 of 8000 steps') ??
                    false),
          ),
        ),
      );
      expect(semantics.label, contains('9 June'));
      expect(semantics.label, contains('547 over goal'));
    });

    testWidgets('tooltip includes year when visible window spans years', (
      tester,
    ) async {
      final points = [
        ChartDayAggregate(
          localDay: DateTime.utc(2025, 12, 31),
          totalSteps: 5000,
        ),
        ChartDayAggregate(
          localDay: DateTime.utc(2026, 1, 1),
          totalSteps: 6000,
        ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
      );

      final core = tester.widget<AstraBarChartCore>(
        find.byType(AstraBarChartCore),
      );
      await tapBarAtIndex(
        tester,
        barIndex: 1,
        barCount: 2,
        barWidth: core.barWidth,
        plotWidth: 320 - 36 - 16,
      );

      expect(find.text('1 January 2026\n6000/8000 steps'), findsOneWidget);
    });
  });
}
