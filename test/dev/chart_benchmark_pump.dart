import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/dev/chart_benchmark.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [ChartBenchmarkWidgetPump] for widget tests.
///
/// Pumps the 7d chart only — 30-bar fl_chart layout can hang some desktop CI
/// hosts. Device runs use [createOverlayStepBarChartPump] (7d + 30d).
ChartBenchmarkWidgetPump createTestStepBarChartPump(WidgetTester tester) {
  return ({
    required List<ChartDayAggregate> points7d,
    required List<ChartDayAggregate> points30d,
    required int dailyGoal,
  }) async {
    await _pumpReadyChart(tester, points: points7d, dailyGoal: dailyGoal);
    assert(points30d.isNotEmpty);
  };
}

Future<void> _pumpReadyChart(
  WidgetTester tester, {
  required List<ChartDayAggregate> points,
  required int dailyGoal,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAstraLightTheme(),
      home: Scaffold(
        body: SizedBox(
          height: 240,
          child: StepBarChart(
            points: points,
            dailyGoal: dailyGoal,
            status: HistoryStatus.ready,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
