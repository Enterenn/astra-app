/// Display formatting for derived activity metrics (Story 6.1).
library;

/// Integer kcal, no unit suffix (label is separate in the stats row).
String formatKcal(int kcal) => kcal.toString();

/// One decimal km, half-up rounding.
String formatDistanceKm(double distanceKm) {
  final rounded = (distanceKm * 10).round() / 10;
  return rounded.toStringAsFixed(1);
}

/// `HH:MM:SS` with zero-padded hours, minutes, and seconds.
String formatWalkingDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
