// User-facing display unit preferences (Story 10.6).
//
// Canonical body values (`height_cm`, `weight_kg`) and internal distance math
// stay metric — these enums control display labels and editor input modes.

import 'package:astra_app/core/constants/preference_keys.dart';

enum DistanceDisplayUnit {
  metric,
  imperial;

  String get displayLabel => switch (this) {
    DistanceDisplayUnit.metric => 'Metric',
    DistanceDisplayUnit.imperial => 'Imperial',
  };

  String get storageValue => switch (this) {
    DistanceDisplayUnit.metric => 'metric',
    DistanceDisplayUnit.imperial => 'imperial',
  };
}

enum WeightDisplayUnit {
  kg,
  lb;

  String get displayLabel => switch (this) {
    WeightDisplayUnit.kg => 'Kg',
    WeightDisplayUnit.lb => 'lb',
  };

  String get storageValue => switch (this) {
    WeightDisplayUnit.kg => 'kg',
    WeightDisplayUnit.lb => 'lb',
  };
}

enum HeightDisplayUnit {
  cm,
  ftIn;

  String get displayLabel => switch (this) {
    HeightDisplayUnit.cm => 'cm',
    HeightDisplayUnit.ftIn => 'ft+in',
  };

  String get storageValue => switch (this) {
    HeightDisplayUnit.cm => 'cm',
    HeightDisplayUnit.ftIn => 'ft_in',
  };
}

DistanceDisplayUnit parseDistanceDisplayUnit(String? raw) {
  return switch (raw?.trim()) {
    'imperial' => DistanceDisplayUnit.imperial,
    kDefaultDistanceDisplayUnit => DistanceDisplayUnit.metric,
    _ => DistanceDisplayUnit.metric,
  };
}

WeightDisplayUnit parseWeightDisplayUnit(String? raw) {
  return switch (raw?.trim()) {
    'lb' => WeightDisplayUnit.lb,
    kDefaultWeightDisplayUnit => WeightDisplayUnit.kg,
    _ => WeightDisplayUnit.kg,
  };
}

HeightDisplayUnit parseHeightDisplayUnit(String? raw) {
  return switch (raw?.trim()) {
    'ft_in' => HeightDisplayUnit.ftIn,
    kDefaultHeightDisplayUnit => HeightDisplayUnit.cm,
    _ => HeightDisplayUnit.cm,
  };
}
