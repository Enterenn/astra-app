/// Locale-friendly step count formatting without the `intl` package.
///
/// Uses a thin space (U+2009) as thousands separator, e.g. `10 847`.
String formatStepCount(int count) {
  final digits = count.abs().toString();
  if (digits.length <= 3) {
    return digits;
  }

  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('\u2009');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
