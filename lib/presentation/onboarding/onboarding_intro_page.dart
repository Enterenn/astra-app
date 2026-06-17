import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class OnboardingIntroPage extends StatefulWidget {
  const OnboardingIntroPage({super.key});

  @override
  State<OnboardingIntroPage> createState() => _OnboardingIntroPageState();
}

class _OnboardingIntroPageState extends State<OnboardingIntroPage> {
  bool _disclaimerExpanded = false;

  static const _headline = 'Your Health. Your Phone. Period.';

  static const _cardParagraphOne =
      'Astra tracks your movement, habits, and health metrics using only your '
      "device's built-in sensors. No accounts, no cloud leakage.";

  static const _cardParagraphTwo =
      'Your personal evolution belongs to you—and only you.';

  static const _disclaimerBody =
      'All data stays on this device. Sensors run locally—nothing is uploaded, '
      'and no account is required to use Astra.';

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
            style: AstraTypography.titleFor(colors),
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
          const SizedBox(height: AstraSpacing.kSpaceMd),
          InkWell(
            onTap: () {
              setState(() => _disclaimerExpanded = !_disclaimerExpanded);
            },
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AstraSpacing.kSpaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn more',
                    style: AstraTypography.labelFor(colors).copyWith(
                      color: colors.accentPrimary,
                    ),
                  ),
                  if (_disclaimerExpanded) ...[
                    const SizedBox(height: AstraSpacing.kSpaceSm),
                    Text(
                      _disclaimerBody,
                      style: AstraTypography.bodyFor(colors).copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
