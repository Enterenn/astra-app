import '../../core/constants/display_unit_preferences.dart';

class UnitsState {
  const UnitsState({
    required this.distanceUnit,
    required this.weightUnit,
    required this.heightUnit,
  });

  final DistanceDisplayUnit distanceUnit;
  final WeightDisplayUnit weightUnit;
  final HeightDisplayUnit heightUnit;
}
