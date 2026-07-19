import 'package:flutter/material.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/astra_theme_preference.dart';

export '../../core/constants/astra_theme_preference.dart';

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
