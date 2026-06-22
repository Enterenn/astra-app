import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Shared chrome for onboarding weight/height picker steps.
class OnboardingMetricPickerLayout extends StatelessWidget {
  const OnboardingMetricPickerLayout({
    required this.title,
    required this.unitSelector,
    required this.ruler,
    super.key,
  });

  final String title;
  final Widget unitSelector;
  final Widget ruler;

  /// Horizontal padding inside each unit segment (mockup: 36px).
  static const unitSegmentHorizontalPadding = 36.0;

  /// Vertical margin above and below the ruler tick band.
  static const sliderVerticalMargin = AstraSpacing.kSpace2xl;

  /// Gap between tick band and unit label under the slider.
  static const unitLabelGap = AstraSpacing.kSpaceMd;

  /// Center selection indicator bar height.
  static const centerIndicatorHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AstraTypography.titleFor(colors),
          ),
          const SizedBox(height: AstraSpacing.kSpaceXl),
          Center(child: unitSelector),
          const SizedBox(height: AstraSpacing.kSpaceLg),
          ruler,
          const SizedBox(height: AstraSpacing.kSpaceMd),
          Text(
            l10n.onboardingOptionalMetricsHint,
            textAlign: TextAlign.center,
            style: AstraTypography.captionFor(colors),
          ),
        ],
      ),
    );
  }
}
