import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Dashed stepped polyline for per-day historical goals on bar charts.
class GoalStepLinePainter extends CustomPainter {
  GoalStepLinePainter({
    required this.goals,
    required this.maxY,
    required this.barCount,
    required this.color,
    this.leftReserved = 36,
    this.bottomReserved = 24,
    this.strokeWidth = 1.5,
    this.dashPattern = const [6, 4],
  });

  final List<int> goals;
  final double maxY;
  final int barCount;
  final Color color;
  final double leftReserved;
  final double bottomReserved;
  final double strokeWidth;
  final List<int> dashPattern;

  @override
  void paint(Canvas canvas, Size size) {
    if (goals.isEmpty || barCount <= 0 || maxY <= 0) {
      return;
    }

    final plotWidth = math.max(size.width - leftReserved, 0);
    final plotHeight = math.max(size.height - bottomReserved, 0);
    if (plotWidth <= 0 || plotHeight <= 0) {
      return;
    }

    final slotWidth = plotWidth / barCount;
    final path = Path();

    double barCenterX(int index) => leftReserved + slotWidth * index + slotWidth / 2;

    double goalY(int goal) => plotHeight * (1 - goal / maxY);

    path.moveTo(barCenterX(0), goalY(goals.first));
    for (var index = 1; index < goals.length; index++) {
      final x = barCenterX(index);
      path.lineTo(x, goalY(goals[index - 1]));
      if (goals[index] != goals[index - 1]) {
        path.lineTo(x, goalY(goals[index]));
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      _drawDashedPath(canvas, metric, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, ui.PathMetric metric, Paint paint) {
    final dashLength = dashPattern.isNotEmpty ? dashPattern.first.toDouble() : 6;
    final gapLength = dashPattern.length > 1 ? dashPattern[1].toDouble() : 4;
    var distance = 0.0;
    var draw = true;

    while (distance < metric.length) {
      final segmentLength = draw ? dashLength : gapLength;
      final end = math.min(distance + segmentLength, metric.length);
      if (draw) {
        canvas.drawPath(metric.extractPath(distance, end), paint);
      }
      distance = end;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant GoalStepLinePainter oldDelegate) {
    return oldDelegate.goals != goals ||
        oldDelegate.maxY != maxY ||
        oldDelegate.barCount != barCount ||
        oldDelegate.color != color ||
        oldDelegate.leftReserved != leftReserved ||
        oldDelegate.bottomReserved != bottomReserved;
  }
}
