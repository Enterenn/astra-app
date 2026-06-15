import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/constants/preference_keys.dart';
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

    test('zero distance shows 0.0 in both units', () {
      expect(
        formatDisplayDistanceValue(0, DistanceDisplayUnit.metric),
        '0.0',
      );
      expect(
        formatDisplayDistanceValue(0, DistanceDisplayUnit.imperial),
        '0.0',
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
      expect(formatDisplayHeight(null, HeightDisplayUnit.ftIn), 'Not set');
    });

    test('metric shows cm', () {
      expect(formatDisplayHeight(180, HeightDisplayUnit.cm), '180 cm');
    });

    test('imperial shows ft and in', () {
      expect(formatDisplayHeight(180, HeightDisplayUnit.ftIn), '5 ft 11 in');
    });

    test('boundary heights at min and max cm', () {
      expect(formatDisplayHeight(kMinHeightCm, HeightDisplayUnit.ftIn), '3 ft 3 in');
      expect(formatDisplayHeight(kMaxHeightCm, HeightDisplayUnit.ftIn), '8 ft 2 in');
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

    test('boundary weights at min and max kg in lb', () {
      expect(formatDisplayWeight(kMinWeightKg, WeightDisplayUnit.lb), '66.1 lb');
      expect(formatDisplayWeight(kMaxWeightKg, WeightDisplayUnit.lb), '661.4 lb');
    });
  });

  group('heightCmToFtIn / heightFtInToCm', () {
    test('180 cm round-trips to 5 ft 11 in', () {
      final ftIn = heightCmToFtIn(180);
      expect(ftIn.feet, 5);
      expect(ftIn.inches, 11);
      expect(heightFtInToCm(feet: 5, inches: 11), 180);
    });

    test('round-trip within ±1 cm tolerance', () {
      for (final cm in [150, 180, 200, 220]) {
        final ftIn = heightCmToFtIn(cm);
        final back = heightFtInToCm(feet: ftIn.feet, inches: ftIn.inches);
        expect(back, isNotNull);
        expect((back! - cm).abs(), lessThanOrEqualTo(1));
      }
    });

    test('min cm boundary display rounds below canonical min on inverse', () {
      final ftIn = heightCmToFtIn(kMinHeightCm);
      expect(ftIn.feet, 3);
      expect(ftIn.inches, 3);
      // 3 ft 3 in → 99 cm; editor validation rejects (below kMinHeightCm).
      expect(heightFtInToCm(feet: ftIn.feet, inches: ftIn.inches), isNull);
    });

    test('rejects inches outside 0–11', () {
      expect(heightFtInToCm(feet: 5, inches: 12), isNull);
      expect(heightFtInToCm(feet: 5, inches: -1), isNull);
    });

    test('rejects out-of-range canonical cm after conversion', () {
      expect(heightFtInToCm(feet: 2, inches: 0), isNull);
      expect(heightFtInToCm(feet: 9, inches: 0), isNull);
    });
  });

  group('weightKgToDisplayLb / displayLbToWeightKg', () {
    test('72.5 kg round-trips through lb', () {
      final lb = weightKgToDisplayLb(72.5);
      expect(lb, closeTo(159.8, 0.1));
      expect(displayLbToWeightKg(lb), 72.5);
    });

    test('159.8 lb converts to 72.5 kg', () {
      expect(displayLbToWeightKg(159.8), 72.5);
    });

    test('round-trip preserves one-decimal kg', () {
      for (final kg in [30.0, 72.5, 150.0, 300.0]) {
        final lb = weightKgToDisplayLb(kg);
        expect(displayLbToWeightKg(lb), kg);
      }
    });
  });
}
