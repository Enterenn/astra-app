import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({super.key});

  static const _headline = 'Your Health. Your Phone. Period.';

  static const _cardParagraphOne =
      'Astra tracks your movement, habits, and health metrics using only your '
      "device's built-in sensors. No accounts, no cloud leakage.";

  static const _cardParagraphTwo =
      'Your personal evolution belongs to you—and only you.';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: AstraTypography.onboardingIntroTitleFor(colors),
          ),
          const SizedBox(height: AstraSpacing.kSpaceXl),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AstraSpacing.kCardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cardParagraphOne,
                    style: AstraTypography.bodyFor(colors),
                  ),
                  const SizedBox(height: AstraSpacing.kSpaceMd),
                  Text(
                    _cardParagraphTwo,
                    style: AstraTypography.bodyFor(colors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
