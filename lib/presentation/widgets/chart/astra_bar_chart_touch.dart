import 'package:flutter/material.dart';

import '../../../core/constants/astra_colors.dart';
import '../../../core/constants/astra_typography.dart';

/// Tooltip text styling shared by native ASTRA bar charts.
TextStyle astraBarTooltipPrimaryStyle(AstraColors colors) {
  return AstraTypography.captionFor(colors).copyWith(
    color: colors.textPrimary,
    fontWeight: FontWeight.w600,
  );
}

/// Default tooltip container decoration for chart tooltips.
BoxDecoration astraBarTooltipDecoration(AstraColors colors) {
  return BoxDecoration(
    color: colors.bgElevated,
    borderRadius: BorderRadius.circular(8),
  );
}

/// Shared tooltip padding for chart bar selection.
const kAstraBarTooltipPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 8,
);

const kAstraBarTooltipMargin = 8.0;
