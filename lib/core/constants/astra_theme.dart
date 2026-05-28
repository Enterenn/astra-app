import 'package:flutter/material.dart';

import 'astra_colors.dart';
import 'astra_typography.dart';

TextTheme _textTheme(AstraColors colors) => TextTheme(
  displayLarge: TextStyle(
    fontFamily: AstraTypography.darkerGrotesque,
    fontSize: 52,
    fontWeight: FontWeight.w600,
    height: 1.05,
    color: colors.textPrimary,
  ),
  headlineMedium: TextStyle(
    fontFamily: AstraTypography.darkerGrotesque,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: colors.textPrimary,
  ),
  titleMedium: TextStyle(
    fontFamily: AstraTypography.figtree,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: colors.textPrimary,
  ),
  bodyLarge: TextStyle(
    fontFamily: AstraTypography.figtree,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.textPrimary,
  ),
  labelLarge: TextStyle(
    fontFamily: AstraTypography.figtree,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: colors.textPrimary,
  ),
  bodySmall: TextStyle(
    fontFamily: AstraTypography.figtree,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: colors.textSecondary,
  ),
  titleSmall: TextStyle(
    fontFamily: AstraTypography.darkerGrotesque,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: colors.textPrimary,
  ),
);

ThemeData buildAstraLightTheme() {
  final colors = AstraColors.light();
  return ThemeData(
    useMaterial3: true,
    fontFamily: AstraTypography.figtree,
    scaffoldBackgroundColor: colors.bgBase,
    colorScheme: ColorScheme.light(
      primary: colors.accentPrimary,
      onPrimary: colors.textInverse,
      surface: colors.bgElevated,
      onSurface: colors.textPrimary,
      error: colors.statusDanger,
      onError: colors.textInverse,
      outline: colors.borderDefault,
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: _textTheme(colors),
  );
}

ThemeData buildAstraDarkTheme() {
  final colors = AstraColors.dark();
  return ThemeData(
    useMaterial3: true,
    fontFamily: AstraTypography.figtree,
    scaffoldBackgroundColor: colors.bgBase,
    colorScheme: ColorScheme.dark(
      primary: colors.accentPrimary,
      onPrimary: colors.textInverse,
      surface: colors.bgElevated,
      onSurface: colors.textPrimary,
      error: colors.statusDanger,
      onError: colors.textInverse,
      outline: colors.borderDefault,
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: _textTheme(colors),
  );
}
