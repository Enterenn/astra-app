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
      expect(colors.bgSubtle, const Color(0xFFEEF0F4));
      expect(colors.borderDefault, const Color(0xFFD1D5DB));
      expect(colors.borderFocus, const Color(0xFF9CA3AF));
      expect(colors.textPrimary, const Color(0xFF0F1114));
      expect(colors.textSecondary, const Color(0xFF4B5563));
      expect(colors.textMuted, const Color(0xFF6B7280));
      expect(colors.textInverse, const Color(0xFFF4F5F7));
    });

    test('shared accent, data, and status tokens match UX hex', () {
      expect(colors.accentPrimary, const Color(0xFFEAD55E));
      expect(colors.accentSecondary, const Color(0xFF94A3B8));
      expect(colors.dataNegative, const Color(0xFFFCA5A5));
      expect(colors.statusOk, const Color(0xFF86EFAC));
      expect(colors.statusStale, const Color(0xFFFBBF24));
      expect(colors.statusDanger, const Color(0xFFF87171));
      expect(colors.statusInfo, const Color(0xFF93C5FD));
    });

    test('opacity-derived tokens use UX alpha values', () {
      expect(colors.accentPrimaryMuted.a, closeTo(0.28, 0.01));
      expect(colors.dataPositive.a, closeTo(0.8, 0.01));
      expect(colors.dataGoalLine.a, closeTo(0.35, 0.01));
    });
  });

  group('AstraColors.dark', () {
    late AstraColors colors;

    setUp(() => colors = AstraColors.dark());

    test('surface and text tokens match UX hex', () {
      expect(colors.bgBase, const Color(0xFF0F1114));
      expect(colors.bgElevated, const Color(0xFF1A1D23));
      expect(colors.bgSubtle, const Color(0xFF252830));
      expect(colors.borderDefault, const Color(0xFF2E3340));
      expect(colors.borderFocus, const Color(0xFF4A5568));
      expect(colors.textPrimary, const Color(0xFFF4F5F7));
      expect(colors.textSecondary, const Color(0xFF9CA3AF));
      expect(colors.textMuted, const Color(0xFF6B7280));
      expect(colors.textInverse, const Color(0xFF0F1114));
    });

    test('shared accent, data, and status tokens match UX hex', () {
      expect(colors.accentPrimary, const Color(0xFFEAD55E));
      expect(colors.accentSecondary, const Color(0xFF94A3B8));
      expect(colors.dataNegative, const Color(0xFFFCA5A5));
      expect(colors.statusOk, const Color(0xFF86EFAC));
      expect(colors.statusStale, const Color(0xFFFBBF24));
      expect(colors.statusDanger, const Color(0xFFF87171));
      expect(colors.statusInfo, const Color(0xFF93C5FD));
    });

    test('opacity-derived tokens use UX alpha values', () {
      expect(colors.accentPrimaryMuted.a, closeTo(0.28, 0.01));
      expect(colors.dataPositive.a, closeTo(0.8, 0.01));
      expect(colors.dataGoalLine.a, closeTo(0.35, 0.01));
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
