import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_core.dart';
import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_painter.dart';
import 'package:astra_app/presentation/widgets/chart/astra_single_goal_line_painter.dart';
import 'package:astra_app/presentation/widgets/chart/goal_step_line_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool hasGoalStepLinePainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((paint) => paint.painter is GoalStepLinePainter);
}

bool hasSingleGoalLinePainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((paint) => paint.painter is AstraSingleGoalLinePainter);
}

/// Taps the plot area at the center X of [barIndex] for the given layout.
Future<void> tapBarAtIndex(
  WidgetTester tester, {
  required int barIndex,
  required int barCount,
  required double barWidth,
  required double plotWidth,
  double plotTop = 0,
}) async {
  final centerX = barCenterPlotX(
    index: barIndex,
    plotWidth: plotWidth,
    barCount: barCount,
    barWidth: barWidth,
  );
  await tapPlotAtLocalX(
    tester,
    localX: centerX,
    plotTop: plotTop,
  );
}

/// Taps the plot area at [localX] (plot coordinates, excluding left axis).
Future<void> tapPlotAtLocalX(
  WidgetTester tester, {
  required double localX,
  double plotTop = 0,
}) async {
  final plotFinder = find.byType(AstraBarChartCore);
  final plotBox = tester.getRect(plotFinder);
  await tester.tapAt(
    Offset(
      plotBox.left + kAstraBarChartLeftAxisReserved + localX,
      plotBox.top + plotTop + 20,
    ),
  );
  await tester.pump();
}

/// Reads bar colors from the chart painter delegate.
List<Color> barColorsFromChart(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<AstraBarChartPainter>()
      .firstOrNull;
  if (painter == null) {
    return const [];
  }
  return [
    for (var i = 0; i < painter.values.length; i++)
      painter.barColor(i, painter.selectedIndex == i),
  ];
}
