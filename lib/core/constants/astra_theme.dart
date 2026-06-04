import 'package:flutter/material.dart';

import 'astra_colors.dart';
import 'astra_typography.dart';
import 'astra_spacing.dart';

TextTheme _textTheme(AstraColors colors) => TextTheme(
  displayLarge: AstraTypography.displayFor(colors),
  headlineMedium: AstraTypography.titleFor(colors),
  titleMedium: AstraTypography.headlineFor(colors),
  bodyLarge: AstraTypography.bodyFor(colors),
  labelLarge: AstraTypography.labelFor(colors),
  bodySmall: AstraTypography.captionFor(colors),
  titleSmall: AstraTypography.dataFor(colors),
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
    // Legacy M3 bar theme — shell uses AppBottomNav (Story 5.7); kept for any Material NavigationBar.
    navigationBarTheme: NavigationBarThemeData(
      height: AstraSpacing.kBottomTabBarHeight,
      backgroundColor: colors.bgElevated,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colors.accentPrimary
            : colors.textMuted;
        return IconThemeData(color: color);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colors.accentPrimary
            : colors.textMuted;
        return AstraTypography.labelFor(colors).copyWith(color: color);
      }),
    ),
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
    // Legacy M3 bar theme — shell uses AppBottomNav (Story 5.7); kept for any Material NavigationBar.
    navigationBarTheme: NavigationBarThemeData(
      height: AstraSpacing.kBottomTabBarHeight,
      backgroundColor: colors.bgElevated,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colors.accentPrimary
            : colors.textMuted;
        return IconThemeData(color: color);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? colors.accentPrimary
            : colors.textMuted;
        return AstraTypography.labelFor(colors).copyWith(color: color);
      }),
    ),
  );
}
