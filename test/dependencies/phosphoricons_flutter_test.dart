import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Compile-time guard for Story 5.7 four-tab nav icons (UX §1.6).
void main() {
  test('phosphoricons_flutter exposes four-tab PhosphorIconsRegular icons', () {
    expect(PhosphorIconsRegular.footprints.codePoint, greaterThan(0));
    expect(PhosphorIconsRegular.chartBar.codePoint, greaterThan(0));
    expect(PhosphorIconsRegular.database.codePoint, greaterThan(0));
    expect(PhosphorIconsRegular.user.codePoint, greaterThan(0));
  });
}
