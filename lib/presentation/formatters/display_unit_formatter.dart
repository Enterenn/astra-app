import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
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
    final ftIn = heightCmToFtIn(heightCm);
    return '${ftIn.feet} ft ${ftIn.inches} in';
  }
  return '$heightCm cm';
}

String formatDisplayWeight(double? weightKg, WeightDisplayUnit unit) {
  if (weightKg == null) {
    return 'Not set';
  }
  if (unit == WeightDisplayUnit.lb) {
    final pounds = weightKgToDisplayLb(weightKg);
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

/// Splits canonical cm into feet/inches using the same rounding as display.
({int feet, int inches}) heightCmToFtIn(int heightCm) {
  final totalInches = (heightCm / _cmPerInch).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

/// Converts feet/inches input to canonical cm (rounded to nearest int).
///
/// Returns `null` when [inches] is outside 0–11 or result is out of range.
int? heightFtInToCm({required int feet, required int inches}) {
  if (inches < 0 || inches > 11) {
    return null;
  }
  final heightCm = (((feet * 12) + inches) * _cmPerInch).round();
  if (heightCm < kMinHeightCm || heightCm > kMaxHeightCm) {
    return null;
  }
  return heightCm;
}

/// Converts canonical kg to display pounds (no rounding — for editor pre-fill).
double weightKgToDisplayLb(double weightKg) => weightKg * _lbPerKg;

/// Converts display pounds to canonical kg (one decimal, half-up).
double displayLbToWeightKg(double lb) => (lb / _lbPerKg * 10).round() / 10;
