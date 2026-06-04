import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const neutralGray = Color(0xFFA0A0AA);

  group('AstraColors.light (default orange)', () {
    late AstraColors colors;

    setUp(() => colors = AstraColors.light());

    test('surface and text tokens match locked neutrals', () {
      expect(colors.bgBase, const Color(0xFFF8F9FB));
      expect(colors.bgElevated, const Color(0xFFFFFFFF));
      expect(colors.bgSubtle, const Color(0xFFEEF0F4));
      expect(colors.textPrimary, const Color(0xFF323337));
      expect(colors.neutralGray, neutralGray);
      expect(colors.borderDefault, neutralGray);
    });

    test('orange preset accent and derived tokens', () {
      expect(colors.accentPrimary, const Color(0xFFFBB577));
      expect(colors.accentSecondary, const Color(0xFF59402A));
      expect(colors.borderPrimary, colors.accentPrimary);
      expect(colors.dataPositive, colors.accentPrimary);
      expect(colors.statusOk, const Color(0xFF7CEA89));
      expect(colors.statusDanger, const Color(0xFFE52F2F));
    });

    test('opacity-derived tokens use locked alpha values', () {
      expect(colors.accentPrimaryMuted.a, closeTo(0.28, 0.01));
      expect(colors.dataNegative.a, closeTo(0.33, 0.01));
      expect(colors.dataGoalLine.a, closeTo(0.35, 0.01));
    });
  });

  group('AstraColors.dark (default orange)', () {
    late AstraColors colors;

    setUp(() => colors = AstraColors.dark());

    test('surface and text tokens match locked neutrals', () {
      expect(colors.bgBase, const Color(0xFF101115));
      expect(colors.bgElevated, const Color(0xFF1A1D26));
      expect(colors.bgSubtle, const Color(0xFF3E4457));
      expect(colors.textPrimary, const Color(0xFFC8C8D7));
      expect(colors.borderDefault, neutralGray);
    });

    test('orange preset accent matches light preset primary', () {
      final light = AstraColors.light();
      expect(colors.accentPrimary, light.accentPrimary);
      expect(colors.accentSecondary, light.accentSecondary);
      expect(colors.statusOk, light.statusOk);
    });
  });

  group('preset-specific accents', () {
    test('blue preset uses locked hex in light theme', () {
      final colors = AstraColors.light(preset: AstraAccentPreset.blue);
      expect(colors.accentPrimary, const Color(0xFF75BDE4));
      expect(colors.accentSecondary, const Color(0xFF274758));
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
