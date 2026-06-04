import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in [MaterialApp] with light/dark Astra themes for the given [preset].
Widget wrapWithAstraTheme(
  Widget child, {
  AstraAccentPreset preset = kDefaultAccentPreset,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: buildAstraLightTheme(preset: preset),
    darkTheme: buildAstraDarkTheme(preset: preset),
    themeMode: themeMode,
    home: Scaffold(body: child),
  );
}
