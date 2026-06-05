import 'package:astra_app/core/constants/astra_accent_palette.dart';
import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAccentPreset', () {
    test('defaults to orange and maps legacy aliases', () {
      expect(parseAccentPreset(null), AstraAccentPreset.orange);
      expect(parseAccentPreset(''), AstraAccentPreset.orange);
      expect(parseAccentPreset('amber'), AstraAccentPreset.orange);
      expect(parseAccentPreset('cyan'), AstraAccentPreset.blue);
      expect(parseAccentPreset('purple'), AstraAccentPreset.magenta);
      expect(parseAccentPreset(' blue '), AstraAccentPreset.blue);
    });

    test('parses all six English preset IDs', () {
      expect(parseAccentPreset('orange'), AstraAccentPreset.orange);
      expect(parseAccentPreset('red'), AstraAccentPreset.red);
      expect(parseAccentPreset('green'), AstraAccentPreset.green);
      expect(parseAccentPreset('blue'), AstraAccentPreset.blue);
      expect(parseAccentPreset('magenta'), AstraAccentPreset.magenta);
      expect(parseAccentPreset('pink'), AstraAccentPreset.pink);
    });
  });

  group('accentPaletteFor', () {
    test('each preset exposes primary and secondary colors', () {
      for (final preset in AstraAccentPreset.values) {
        final palette = accentPaletteFor(preset);
        expect(palette.primary.value, greaterThan(0));
        expect(palette.secondary.value, greaterThan(0));
      }
    });
  });
}
