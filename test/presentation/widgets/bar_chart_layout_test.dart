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
  });
}
