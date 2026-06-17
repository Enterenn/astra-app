import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../widgets/astra_button.dart';
import 'onboarding_progress_bar.dart';

/// Shared onboarding chrome: segment progress, content slot, footer actions.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    required this.currentStep,
    required this.content,
    required this.showBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.showPrimaryTrailingArrow = false,
    this.onBack,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryEnabled = true,
    super.key,
  });

  final int currentStep;
  final Widget content;
  final bool showBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool showPrimaryTrailingArrow;
  final VoidCallback? onBack;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final primaryEnabled = onPrimary != null && !primaryLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingProgressBar(currentStep: currentStep),
        const SizedBox(height: AstraSpacing.kSpace2xl),
        Expanded(child: content),
        if (secondaryLabel != null && onSecondary != null) ...[
          Center(
            child: AstraButton(
              label: secondaryLabel!,
              variant: AstraButtonVariant.ghost,
              onPressed: secondaryEnabled && !primaryLoading ? onSecondary : null,
            ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
        ],
        Row(
          children: [
            if (showBack)
              IconButton(
                onPressed: primaryLoading ? null : onBack,
                icon: Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: colors.textPrimary,
                ),
                tooltip: 'Back',
              )
            else
              const SizedBox.shrink(),
            const Spacer(),
            AstraButton(
              label: primaryLabel,
              onPressed: primaryEnabled ? onPrimary : null,
              isLoading: primaryLoading,
              compact: true,
              trailing: showPrimaryTrailingArrow && !primaryLoading
                  ? Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: 18,
                      color: colors.accentSecondary,
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
