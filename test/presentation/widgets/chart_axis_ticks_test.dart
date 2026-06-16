import 'package:astra_app/presentation/widgets/chart/chart_axis_ticks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeChartYAxisTicks', () {
    test('returns at least four ticks for typical chart ceilings', () {
      final ticks = computeChartYAxisTicks(
        maxY: 5250,
        referenceValues: const [8000],
      );

      expect(ticks.first, 0);
      expect(ticks.last, 5250);
      expect(ticks.length, greaterThanOrEqualTo(4));
    });

    test('merges reference goal when not too close to an existing tick', () {
      final ticks = computeChartYAxisTicks(
        maxY: 10_500,
        referenceValues: const [8000],
      );

      expect(ticks.any((tick) => tick.round() == 8000), isTrue);
    });

    test('mostCommonChartReferenceValue returns 0 for empty input', () {
      expect(mostCommonChartReferenceValue(const []), 0);
    });
  });
}
