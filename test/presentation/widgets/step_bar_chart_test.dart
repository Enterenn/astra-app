import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/chart/chart_axis_ticks.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bar_chart_touch_test_helper.dart';

void main() {
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
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 240,
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

      expect(find.text(StepBarChart.emptyCopy), findsOneWidget);
    });

    testWidgets('loading state shows seven skeleton bars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: SizedBox(
              height: 240,
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

    testWidgets('ready state builds BarChart without throw', (tester) async {
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
      expect(find.byType(BarChart), findsOneWidget);
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

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.extraLinesData.horizontalLines, hasLength(1));
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

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.extraLinesData.horizontalLines, isEmpty);
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

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final firstBar = barChart.data.barGroups.first.barRods.first.color;
      final secondBar = barChart.data.barGroups.last.barRods.first.color;
      expect(firstBar, isNot(equals(secondBar)));
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

      final chartMaxY = tester.widget<BarChart>(find.byType(BarChart)).data.maxY;
      final ticks = computeChartYAxisTicks(
        maxY: chartMaxY,
        referenceValues: const [8000],
      );

      expect(ticks.length, greaterThanOrEqualTo(4));
      expect(ticks, contains(0));
      expect(ticks.last, chartMaxY);
    });

    testWidgets('bar touch selects bar and enables tooltip indicators', (
      tester,
    ) async {
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

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.barTouchData.enabled, isTrue);
      expect(barChart.data.barTouchData.handleBuiltInTouches, isFalse);

      simulateBarTap(barChart.data.barTouchData, groupIndex: 0);
      await tester.pump();

      final updatedChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(
        updatedChart.data.barGroups.first.showingTooltipIndicators,
        const [0],
      );

      final tooltip = updatedChart.data.barTouchData.touchTooltipData
          .getTooltipItem(
        updatedChart.data.barGroups.first,
        0,
        updatedChart.data.barGroups.first.barRods.first,
        0,
      );
      expect(tooltip?.text, '9 June\n8547/8000 steps');
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

      simulateBarTap(
        tester.widget<BarChart>(find.byType(BarChart)).data.barTouchData,
        groupIndex: 0,
      );
      await tester.pump();

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

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltip = barChart.data.barTouchData.touchTooltipData.getTooltipItem(
        barChart.data.barGroups.last,
        1,
        barChart.data.barGroups.last.barRods.first,
        0,
      );

      expect(tooltip?.text, '1 January 2026\n6000/8000 steps');
    });
  });
}
