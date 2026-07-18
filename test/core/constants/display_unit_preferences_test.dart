import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDistanceDisplayUnit', () {
    test('null and invalid raw resolve to metric default', () {
      expect(parseDistanceDisplayUnit(null), DistanceDisplayUnit.metric);
      expect(parseDistanceDisplayUnit(''), DistanceDisplayUnit.metric);
      expect(parseDistanceDisplayUnit('bogus'), DistanceDisplayUnit.metric);
    });

    test('explicit metric string resolves to metric', () {
      expect(
        parseDistanceDisplayUnit(kDefaultDistanceDisplayUnit),
        DistanceDisplayUnit.metric,
      );
    });

    test('imperial string resolves to imperial', () {
      expect(parseDistanceDisplayUnit('imperial'), DistanceDisplayUnit.imperial);
    });

    test('kDefaultDistanceDisplayUnit matches metric storageValue', () {
      expect(DistanceDisplayUnit.metric.storageValue, kDefaultDistanceDisplayUnit);
    });
  });

  group('parseWeightDisplayUnit', () {
    test('null and invalid raw resolve to kg default', () {
      expect(parseWeightDisplayUnit(null), WeightDisplayUnit.kg);
      expect(parseWeightDisplayUnit(''), WeightDisplayUnit.kg);
      expect(parseWeightDisplayUnit('bogus'), WeightDisplayUnit.kg);
    });

    test('explicit kg string resolves to kg', () {
      expect(
        parseWeightDisplayUnit(kDefaultWeightDisplayUnit),
        WeightDisplayUnit.kg,
      );
    });

    test('lb string resolves to lb', () {
      expect(parseWeightDisplayUnit('lb'), WeightDisplayUnit.lb);
    });

    test('kDefaultWeightDisplayUnit matches kg storageValue', () {
      expect(WeightDisplayUnit.kg.storageValue, kDefaultWeightDisplayUnit);
    });
  });

  group('parseHeightDisplayUnit', () {
    test('null and invalid raw resolve to cm default', () {
      expect(parseHeightDisplayUnit(null), HeightDisplayUnit.cm);
      expect(parseHeightDisplayUnit(''), HeightDisplayUnit.cm);
      expect(parseHeightDisplayUnit('bogus'), HeightDisplayUnit.cm);
    });

    test('explicit cm string resolves to cm', () {
      expect(
        parseHeightDisplayUnit(kDefaultHeightDisplayUnit),
        HeightDisplayUnit.cm,
      );
    });

    test('ft_in string resolves to ftIn', () {
      expect(parseHeightDisplayUnit('ft_in'), HeightDisplayUnit.ftIn);
    });

    test('kDefaultHeightDisplayUnit matches cm storageValue', () {
      expect(HeightDisplayUnit.cm.storageValue, kDefaultHeightDisplayUnit);
    });
  });
}
