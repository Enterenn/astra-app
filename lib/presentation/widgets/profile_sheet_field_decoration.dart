import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Input decoration for profile edit sheets — labels stay readable (not accent-colored).
InputDecoration profileSheetFieldDecoration({
  required AstraColors colors,
  required String labelText,
  String? errorText,
}) {
  final borderRadius = BorderRadius.circular(AstraSpacing.kRadiusSm);
  final borderSide = BorderSide(color: colors.borderDefault);
  final labelStyle = AstraTypography.bodyFor(colors).copyWith(
    color: colors.textMuted,
  );
  final floatingLabelStyle = AstraTypography.bodyFor(colors).copyWith(
    color: colors.textPrimary,
  );

  return InputDecoration(
    labelText: labelText,
    labelStyle: labelStyle,
    floatingLabelStyle: floatingLabelStyle,
    errorText: errorText,
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: colors.statusDanger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: colors.statusDanger),
    ),
  );
}
