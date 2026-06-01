import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

enum AstraButtonVariant { primary, secondary, ghost }

class AstraButton extends StatelessWidget {
  const AstraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AstraButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AstraButtonVariant variant;
  final bool isLoading;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final labelStyle = AstraTypography.labelFor(colors).copyWith(
      color: _labelColor(colors),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AstraSpacing.kMinTouchTarget),
      child: switch (variant) {
        AstraButtonVariant.primary => FilledButton(
            onPressed: _isDisabled ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              backgroundColor: colors.accentPrimary,
              disabledBackgroundColor: colors.accentPrimaryMuted,
              foregroundColor: colors.textInverse,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        AstraButtonVariant.secondary => OutlinedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              foregroundColor: colors.textPrimary,
              disabledForegroundColor: colors.textMuted,
              side: BorderSide(color: colors.borderDefault),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        AstraButtonVariant.ghost => TextButton(
            onPressed: _isDisabled ? null : onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              foregroundColor: colors.textSecondary,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
      },
    );
  }

  Color _labelColor(AstraColors colors) => switch (variant) {
        AstraButtonVariant.primary => colors.textInverse,
        AstraButtonVariant.secondary => colors.textPrimary,
        AstraButtonVariant.ghost => colors.textSecondary,
      };

  Widget _buildChild(TextStyle labelStyle) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: labelStyle.color,
        ),
      );
    }
    return Text(label, style: labelStyle);
  }
}
