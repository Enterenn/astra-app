import 'package:astra_app/presentation/widgets/chart/bar_chart_layout.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/extensions/bar_chart_data_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSpaceAroundBarCenters', () {
    test('matches fl_chart spaceAround positions for equal bar widths', () {
      const barWidth = 18.0;
      const viewWidth = 100.0;
      const barCount = 3;

      final centers = computeSpaceAroundBarCenters(
        viewWidth: viewWidth,
        barCount: barCount,
        barWidth: barWidth,
      );

      final barGroups = List.generate(
        barCount,
        (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: 1,
              width: barWidth,
              color: const Color(0xFF000000),
            ),
          ],
        ),
      );

      final flChartCenters = BarChartData(
        barGroups: barGroups,
        alignment: BarChartAlignment.spaceAround,
      ).calculateGroupsX(viewWidth);

      expect(centers, flChartCenters);
    });
  });
}
