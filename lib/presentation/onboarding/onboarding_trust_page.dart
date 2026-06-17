import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../widgets/astra_button.dart';
import 'onboarding_progress_bar.dart';

class OnboardingTrustPage extends StatelessWidget {
  const OnboardingTrustPage({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingProgressBar(currentStep: 0, totalSteps: 4),
        const SizedBox(height: AstraSpacing.kSpace2xl),
        Text(
          'Your steps stay on this device.',
          style: AstraTypography.titleFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        Text(
          'No account. No cloud. Your step data is stored locally on this '
          'phone and never sent anywhere.',
          style: AstraTypography.bodyFor(colors),
        ),
        const Spacer(),
        AstraButton(
          label: 'Continue',
          onPressed: onContinue,
        ),
      ],
    );
  }
}
