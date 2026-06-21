import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bar_chart_layout.dart';

/// Native bar renderer for ASTRA chart widgets (Impeller-friendly).
class AstraBarChartPainter extends CustomPainter {
  AstraBarChartPainter({
    required this.values,
    required this.maxY,
    required this.barWidth,
    required this.barColor,
    this.selectedIndex,
    this.topCornerRadius = 4,
  });

  final List<double> values;
  final double maxY;
  final double barWidth;
  final Color Function(int index, bool isSelected) barColor;
  final int? selectedIndex;
  final double topCornerRadius;

  final _barFillPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxY <= 0 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final barCenters = computeSpaceAroundBarCenters(
      viewWidth: size.width,
      barCount: values.length,
      barWidth: barWidth,
    );
    if (barCenters.isEmpty) {
      return;
    }

    final halfBar = barWidth / 2;

    for (var index = 0; index < values.length; index++) {
      final value = values[index].clamp(0, maxY);
      if (value <= 0) {
        continue;
      }

      final barHeight = size.height * (value / maxY);
      final left = barCenters[index] - halfBar;
      final top = size.height - barHeight;
      final rect = Rect.fromLTWH(left, top, barWidth, barHeight);

      _barFillPaint.color = barColor(index, selectedIndex == index);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(topCornerRadius),
          topRight: Radius.circular(topCornerRadius),
        ),
        _barFillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AstraBarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.maxY != maxY ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.topCornerRadius != topCornerRadius;
  }
}

/// Maps a local X coordinate in the plot area to a bar index, or null if outside.
int? barIndexAtPlotX({
  required double localX,
  required double plotWidth,
  required int barCount,
  required double barWidth,
}) {
  if (barCount <= 0 || plotWidth <= 0) {
    return null;
  }

  final centers = computeSpaceAroundBarCenters(
    viewWidth: plotWidth,
    barCount: barCount,
    barWidth: barWidth,
  );
  final halfBar = barWidth / 2;

  for (var index = 0; index < centers.length; index++) {
    if ((localX - centers[index]).abs() <= halfBar) {
      return index;
    }
  }

  return null;
}

/// Bar center X in plot coordinates for tooltip positioning.
double barCenterPlotX({
  required int index,
  required double plotWidth,
  required int barCount,
  required double barWidth,
}) {
  final centers = computeSpaceAroundBarCenters(
    viewWidth: plotWidth,
    barCount: barCount,
    barWidth: barWidth,
  );
  if (index < 0 || index >= centers.length) {
    return plotWidth / 2;
  }
  return centers[index];
}

/// Bar top Y in plot coordinates for tooltip positioning.
double barTopPlotY({
  required double value,
  required double maxY,
  required double plotHeight,
}) {
  if (maxY <= 0) {
    return plotHeight;
  }
  final clamped = math.max(value, 0);
  return plotHeight * (1 - clamped / maxY);
}
