import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Horizontal dashed goal reference line for uniform daily goals.
class AstraSingleGoalLinePainter extends CustomPainter {
  AstraSingleGoalLinePainter({
    required this.goalY,
    required this.color,
    this.strokeWidth = 1.5,
    this.dashPattern = const [6, 4],
  });

  /// Goal level mapped to canvas Y (0 = top of plot).
  final double goalY;
  final Color color;
  final double strokeWidth;
  final List<int> dashPattern;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || goalY < 0 || goalY > size.height) {
      return;
    }

    final path = Path()
      ..moveTo(0, goalY)
      ..lineTo(size.width, goalY);

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
  bool shouldRepaint(covariant AstraSingleGoalLinePainter oldDelegate) {
    return oldDelegate.goalY != goalY ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
