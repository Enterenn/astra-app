import 'package:astra_app/core/constants/astra_accent_palette.dart';
import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAccentPreset', () {
    test('defaults to orange for null and unknown values', () {
      expect(parseAccentPreset(null), AstraAccentPreset.orange);
      expect(parseAccentPreset(''), AstraAccentPreset.orange);
      expect(parseAccentPreset('amber'), AstraAccentPreset.orange);
    });

    test('maps legacy cyan and purple aliases', () {
      expect(parseAccentPreset('cyan'), AstraAccentPreset.blue);
      expect(parseAccentPreset('purple'), AstraAccentPreset.magenta);
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

  group('accentPaletteFor locked hex table', () {
    const expected = <AstraAccentPreset, (int primary, int secondary)>{
      AstraAccentPreset.orange: (0xFFFBB577, 0xFF59402A),
      AstraAccentPreset.red: (0xFFDB5858, 0xFF4C2020),
      AstraAccentPreset.green: (0xFF79D676, 0xFF295128),
      AstraAccentPreset.blue: (0xFF75BDE4, 0xFF274758),
      AstraAccentPreset.magenta: (0xFF7D81EF, 0xFF34355B),
      AstraAccentPreset.pink: (0xFFE684C7, 0xFF5D2D4E),
    };

    for (final entry in expected.entries) {
      test('${entry.key.name} primary and secondary hex', () {
        final palette = accentPaletteFor(entry.key);
        expect(palette.primary, Color(entry.value.$1));
        expect(palette.secondary, Color(entry.value.$2));
      });
    }
  });
}
