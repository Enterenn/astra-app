import '../../core/constants/display_unit_preferences.dart';
import 'activity_metrics_formatter.dart';

const _kmPerMile = 1.609344;
const _lbPerKg = 2.2046226218;
const _cmPerInch = 2.54;

/// One decimal miles, half-up rounding (display layer only).
String formatDisplayDistanceValue(
  double distanceKm,
  DistanceDisplayUnit unit,
) {
  if (unit == DistanceDisplayUnit.imperial) {
    final miles = distanceKm / _kmPerMile;
    final rounded = (miles * 10).round() / 10;
    return rounded.toStringAsFixed(1);
  }
  return formatDistanceKm(distanceKm);
}

String displayDistanceUnitLabel(DistanceDisplayUnit unit) {
  return unit == DistanceDisplayUnit.imperial ? 'Mi' : 'Km';
}

String formatDisplayHeight(int? heightCm, HeightDisplayUnit unit) {
  if (heightCm == null) {
    return 'Not set';
  }
  if (unit == HeightDisplayUnit.ftIn) {
    final totalInches = (heightCm / _cmPerInch).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet ft $inches in';
  }
  return '$heightCm cm';
}

String formatDisplayWeight(double? weightKg, WeightDisplayUnit unit) {
  if (weightKg == null) {
    return 'Not set';
  }
  if (unit == WeightDisplayUnit.lb) {
    final pounds = weightKg * _lbPerKg;
    if (pounds == pounds.roundToDouble()) {
      return '${pounds.round()} lb';
    }
    return '${pounds.toStringAsFixed(1)} lb';
  }
  if (weightKg == weightKg.roundToDouble()) {
    return '${weightKg.toInt()} kg';
  }
  return '${weightKg.toStringAsFixed(1)} kg';
}
