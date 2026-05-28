import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AstraColors.light', () {
    late AstraColors colors;

    setUp(() => colors = AstraColors.light());

    test('surface and text tokens match UX hex', () {
      expect(colors.bgBase, const Color(0xFFF8F9FB));
      expect(colors.bgElevated, const Color(0xFFFFFFFF));
      expect(colors.textPrimary, const Color(0xFF0F1114));
    });

    test('shared accent and status tokens match UX hex', () {
      expect(colors.accentPrimary, const Color(0xFFEAD55E));
      expect(colors.statusDanger, const Color(0xFFF87171));
      expect(colors.statusOk, const Color(0xFF86EFAC));
    });
  });

  group('AstraColors.dark', () {
    late AstraColors colors;

    setUp(() => colors = AstraColors.dark());

    test('surface and text tokens match UX hex', () {
      expect(colors.bgBase, const Color(0xFF0F1114));
      expect(colors.bgElevated, const Color(0xFF1A1D23));
      expect(colors.textPrimary, const Color(0xFFF4F5F7));
    });

    test('shared accent and status tokens match UX hex', () {
      expect(colors.accentPrimary, const Color(0xFFEAD55E));
      expect(colors.statusDanger, const Color(0xFFF87171));
      expect(colors.dataNegative, const Color(0xFFFCA5A5));
    });
  });

  group('lerp', () {
    test('t=0 preserves light token values', () {
      final light = AstraColors.light();
      final dark = AstraColors.dark();
      final atStart = light.lerp(dark, 0);

      expect(atStart.bgBase, light.bgBase);
      expect(atStart.textPrimary, light.textPrimary);
      expect(atStart.accentPrimary, light.accentPrimary);
    });

    test('t=1 matches dark token values', () {
      final light = AstraColors.light();
      final dark = AstraColors.dark();
      final atEnd = light.lerp(dark, 1);

      expect(atEnd.bgBase, dark.bgBase);
      expect(atEnd.textPrimary, dark.textPrimary);
      expect(atEnd.accentPrimary, dark.accentPrimary);
    });
  });
}
