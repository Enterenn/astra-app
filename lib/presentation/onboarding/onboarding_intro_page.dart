import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingIntroHeadline,
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
                    l10n.onboardingIntroParagraphOne,
                    style: AstraTypography.bodyFor(colors),
                  ),
                  const SizedBox(height: AstraSpacing.kSpaceMd),
                  Text(
                    l10n.onboardingIntroParagraphTwo,
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
