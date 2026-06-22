import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'chart_benchmark.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/l10n_test_helper.dart';

/// Builds a [ChartBenchmarkWidgetPump] for widget tests.
///
/// Pumps the 7d chart only — 30-bar native chart layout can hang some desktop CI
/// hosts. Device runs use [createOverlayStepBarChartPump] (7d + 30d).
ChartBenchmarkWidgetPump createTestStepBarChartPump(WidgetTester tester) {
  return ({
    required List<ChartDayAggregate> points7d,
    required List<ChartDayAggregate> points30d,
    required int dailyGoal,
    required Map<String, int> goalsByDay,
  }) async {
    await _pumpReadyChart(
      tester,
      points: points7d,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
    );
    assert(points30d.isNotEmpty);
  };
}

Future<void> _pumpReadyChart(
  WidgetTester tester, {
  required List<ChartDayAggregate> points,
  required int dailyGoal,
  required Map<String, int> goalsByDay,
}) async {
  await tester.pumpWidget(
    TestMaterialApp(
      theme: buildAstraLightTheme(),
      home: Scaffold(
        body: SizedBox(
          height: StepBarChart.kDailyChartHeight,
          child: StepBarChart(
            points: points,
            dailyGoal: dailyGoal,
            goalsByDay: goalsByDay,
            status: HistoryStatus.ready,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
