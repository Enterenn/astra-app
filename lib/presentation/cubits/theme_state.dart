import 'package:flutter/material.dart';

enum AstraThemePreference { system, light, dark }

class ThemeState {
  const ThemeState({this.preference = AstraThemePreference.system});

  final AstraThemePreference preference;

  ThemeMode get materialThemeMode => switch (preference) {
    AstraThemePreference.system => ThemeMode.system,
    AstraThemePreference.light => ThemeMode.light,
    AstraThemePreference.dark => ThemeMode.dark,
  };
}
