import 'package:astra_app/presentation/widgets/chart/goal_step_line_painter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BarTouchResponse fakeBarTouchResponse({
  required int groupIndex,
  double rodValue = 1000,
}) {
  final group = BarChartGroupData(
    x: groupIndex,
    barRods: [
      BarChartRodData(
        toY: rodValue,
        width: 8,
        color: Colors.blue,
      ),
    ],
  );

  return BarTouchResponse(
    touchLocation: Offset.zero,
    touchChartCoordinate: Offset.zero,
    spot: BarTouchedSpot(
      group,
      groupIndex,
      group.barRods.first,
      0,
      null,
      -1,
      FlSpot(groupIndex.toDouble(), rodValue),
      Offset.zero,
    ),
  );
}

void simulateBarTap(BarTouchData touchData, {required int groupIndex}) {
  touchData.touchCallback?.call(
    FlTapUpEvent(
      TapUpDetails(
        kind: PointerDeviceKind.touch,
        localPosition: Offset.zero,
      ),
    ),
    fakeBarTouchResponse(groupIndex: groupIndex),
  );
}

bool hasGoalStepLinePainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((paint) => paint.painter is GoalStepLinePainter);
}
