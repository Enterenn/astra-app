import 'package:flutter/material.dart';

import 'astra_accent_preset.dart';

/// Accent primary + on-accent secondary for one preset.
@immutable
class AccentPalette {
  const AccentPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;
}

/// Locked preset hex values (Story 5.8, 2026-06-04).
AccentPalette accentPaletteFor(AstraAccentPreset preset) => switch (preset) {
  AstraAccentPreset.orange => const AccentPalette(
    primary: Color(0xFFEDA464),
    secondary: Color(0xFF8A4324),
  ),
  AstraAccentPreset.red => const AccentPalette(
    primary: Color(0xFFE16969),
    secondary: Color(0xFF822828),
  ),
  AstraAccentPreset.green => const AccentPalette(
    primary: Color(0xFF71D086),
    secondary: Color(0xFF2E753E),
  ),
  AstraAccentPreset.blue => const AccentPalette(
    primary: Color(0xFF6EBAFF),
    secondary: Color(0xFF296093),
  ),
  AstraAccentPreset.magenta => const AccentPalette(
    primary: Color(0xFF9384F8),
    secondary: Color(0xFF523C93),
  ),
  AstraAccentPreset.pink => const AccentPalette(
    primary: Color(0xFFF693C2),
    secondary: Color(0xFF933C65),
  ),
};
