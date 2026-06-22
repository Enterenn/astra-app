import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_painter.dart';
import 'package:astra_app/presentation/widgets/chart/bar_chart_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSpaceAroundBarCenters', () {
    test('distributes bar centers evenly for spaceAround alignment', () {
      const barWidth = 18.0;
      const viewWidth = 100.0;
      const barCount = 3;

      final centers = computeSpaceAroundBarCenters(
        viewWidth: viewWidth,
        barCount: barCount,
        barWidth: barWidth,
      );

      expect(centers, hasLength(3));
      expect(centers.first, closeTo(16.667, 0.001));
      expect(centers[1], closeTo(50, 0.001));
      expect(centers.last, closeTo(83.333, 0.001));
    });

    test('returns empty list for zero bars or width', () {
      expect(
        computeSpaceAroundBarCenters(
          viewWidth: 100,
          barCount: 0,
          barWidth: 8,
        ),
        isEmpty,
      );
      expect(
        computeSpaceAroundBarCenters(
          viewWidth: 0,
          barCount: 3,
          barWidth: 8,
        ),
        isEmpty,
      );
    });
  });

  group('barIndexAtPlotX', () {
    test('returns index when tap is within bar half-width', () {
      const barWidth = 10.0;
      const viewWidth = 100.0;
      const barCount = 3;

      final centers = computeSpaceAroundBarCenters(
        viewWidth: viewWidth,
        barCount: barCount,
        barWidth: barWidth,
      );

      expect(
        barIndexAtPlotX(
          localX: centers[1],
          plotWidth: viewWidth,
          barCount: barCount,
          barWidth: barWidth,
        ),
        1,
      );
    });

    test('returns null when tap is outside all bars', () {
      expect(
        barIndexAtPlotX(
          localX: 0.5,
          plotWidth: 100,
          barCount: 3,
          barWidth: 10,
        ),
        isNull,
      );
    });
  });

  group('AstraBarChartPainter geometry', () {
    test('barTopPlotY scales value against maxY', () {
      expect(
        barTopPlotY(value: 5000, maxY: 10000, plotHeight: 200),
        closeTo(100, 0.001),
      );
      expect(
        barTopPlotY(value: 0, maxY: 10000, plotHeight: 200),
        closeTo(200, 0.001),
      );
    });
  });
}
