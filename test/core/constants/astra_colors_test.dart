import 'package:astra_app/core/constants/astra_accent_palette.dart';
import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AstraColors', () {
    test('light and dark themes use preset accent from palette', () {
      const preset = AstraAccentPreset.blue;
      final palette = accentPaletteFor(preset);
      final light = AstraColors.light(preset: preset);
      final dark = AstraColors.dark(preset: preset);

      expect(light.accentPrimary, palette.primary);
      expect(light.accentSecondary, palette.secondary);
      expect(dark.accentPrimary, palette.primary);
      expect(dark.accentSecondary, palette.secondary);
    });

    test('lerp t=0 preserves light token values', () {
      final light = AstraColors.light();
      final dark = AstraColors.dark();
      final atStart = light.lerp(dark, 0);

      expect(atStart.bgBase, light.bgBase);
      expect(atStart.textPrimary, light.textPrimary);
      expect(atStart.accentPrimary, light.accentPrimary);
    });

    test('lerp t=1 matches dark token values', () {
      final light = AstraColors.light();
      final dark = AstraColors.dark();
      final atEnd = light.lerp(dark, 1);

      expect(atEnd.bgBase, dark.bgBase);
      expect(atEnd.textPrimary, dark.textPrimary);
      expect(atEnd.accentPrimary, dark.accentPrimary);
    });
  });
}
