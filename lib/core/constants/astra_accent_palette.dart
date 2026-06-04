import 'package:flutter/material.dart';

import 'astra_accent_preset.dart';

/// Accent primary + on-accent secondary for one preset.
@immutable
class AccentPalette {
  const AccentPalette({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;
}

/// Locked preset hex values (Story 5.8, 2026-06-04).
AccentPalette accentPaletteFor(AstraAccentPreset preset) =>
    switch (preset) {
      AstraAccentPreset.orange => const AccentPalette(
        primary: Color(0xFFFBB577),
        secondary: Color(0xFF59402A),
      ),
      AstraAccentPreset.red => const AccentPalette(
        primary: Color(0xFFDB5858),
        secondary: Color(0xFF4C2020),
      ),
      AstraAccentPreset.green => const AccentPalette(
        primary: Color(0xFF79D676),
        secondary: Color(0xFF295128),
      ),
      AstraAccentPreset.blue => const AccentPalette(
        primary: Color(0xFF75BDE4),
        secondary: Color(0xFF274758),
      ),
      AstraAccentPreset.magenta => const AccentPalette(
        primary: Color(0xFF7D81EF),
        secondary: Color(0xFF34355B),
      ),
      AstraAccentPreset.pink => const AccentPalette(
        primary: Color(0xFFE684C7),
        secondary: Color(0xFF5D2D4E),
      ),
    };
