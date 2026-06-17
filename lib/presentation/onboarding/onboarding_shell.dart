import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
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
            _FooterPrimaryButton(
              label: primaryLabel,
              onPressed: primaryEnabled ? onPrimary : null,
              isLoading: primaryLoading,
              showTrailingArrow: showPrimaryTrailingArrow,
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterPrimaryButton extends StatelessWidget {
  const _FooterPrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.showTrailingArrow,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final labelStyle = AstraTypography.labelFor(colors).copyWith(
      color: colors.accentSecondary,
    );

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AstraSpacing.kMinTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AstraSpacing.kSpaceLg),
        backgroundColor: colors.accentPrimary,
        disabledBackgroundColor: colors.accentPrimaryMuted,
        foregroundColor: colors.accentSecondary,
        disabledForegroundColor: colors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: labelStyle.color,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle),
                if (showTrailingArrow) ...[
                  const SizedBox(width: AstraSpacing.kSpaceSm),
                  Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 18,
                    color: labelStyle.color,
                  ),
                ],
              ],
            ),
    );
  }
}
