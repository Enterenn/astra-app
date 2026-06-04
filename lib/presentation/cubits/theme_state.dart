import 'package:flutter/material.dart';

import '../../core/constants/astra_accent_preset.dart';

enum AstraThemePreference { system, light, dark }

class ThemeState {
  const ThemeState({
    this.preference = AstraThemePreference.system,
    this.accentPreset = kDefaultAccentPreset,
  });

  final AstraThemePreference preference;
  final AstraAccentPreset accentPreset;

  ThemeMode get materialThemeMode => switch (preference) {
    AstraThemePreference.system => ThemeMode.system,
    AstraThemePreference.light => ThemeMode.light,
    AstraThemePreference.dark => ThemeMode.dark,
  };
}
