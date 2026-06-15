import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/presentation/formatters/display_unit_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDisplayDistanceValue', () {
    test('metric uses km formatter', () {
      expect(
        formatDisplayDistanceValue(4.24, DistanceDisplayUnit.metric),
        '4.2',
      );
    });

    test('imperial converts to miles with one decimal', () {
      expect(
        formatDisplayDistanceValue(10, DistanceDisplayUnit.imperial),
        '6.2',
      );
    });
  });

  group('displayDistanceUnitLabel', () {
    test('returns Km or Mi', () {
      expect(displayDistanceUnitLabel(DistanceDisplayUnit.metric), 'Km');
      expect(displayDistanceUnitLabel(DistanceDisplayUnit.imperial), 'Mi');
    });
  });

  group('formatDisplayHeight', () {
    test('null shows Not set', () {
      expect(formatDisplayHeight(null, HeightDisplayUnit.cm), 'Not set');
    });

    test('metric shows cm', () {
      expect(formatDisplayHeight(180, HeightDisplayUnit.cm), '180 cm');
    });

    test('imperial shows ft and in', () {
      expect(formatDisplayHeight(180, HeightDisplayUnit.ftIn), '5 ft 11 in');
    });
  });

  group('formatDisplayWeight', () {
    test('null shows Not set', () {
      expect(formatDisplayWeight(null, WeightDisplayUnit.kg), 'Not set');
    });

    test('metric shows kg', () {
      expect(formatDisplayWeight(72.5, WeightDisplayUnit.kg), '72.5 kg');
      expect(formatDisplayWeight(72, WeightDisplayUnit.kg), '72 kg');
    });

    test('imperial shows lb', () {
      expect(formatDisplayWeight(72.5, WeightDisplayUnit.lb), '159.8 lb');
      expect(formatDisplayWeight(72, WeightDisplayUnit.lb), '158.7 lb');
    });
  });
}
