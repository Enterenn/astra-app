import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_pressable.dart';

enum AstraButtonVariant { primary, secondary, ghost, danger }

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

  static bool _isInteractive(Set<WidgetState> states) {
    return states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final labelStyle = AstraTypography.labelFor(colors).copyWith(
      color: _labelColor(colors),
    );

    return AstraPressable(
      enabled: !_isDisabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AstraSpacing.kMinTouchTarget,
        ),
        child: switch (variant) {
        AstraButtonVariant.primary => FilledButton(
            onPressed: _isDisabled ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              backgroundColor: colors.accentPrimary,
              disabledBackgroundColor: colors.accentPrimaryMuted,
              foregroundColor: colors.accentSecondary,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        AstraButtonVariant.secondary => OutlinedButton(
            onPressed: _isDisabled ? null : onPressed,
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(
                const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              ),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (_isDisabled) {
                  return colors.textMuted;
                }
                return colors.textPrimary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (_isDisabled) {
                  return Colors.transparent;
                }
                if (_isInteractive(states)) {
                  return colors.borderDefault;
                }
                return Colors.transparent;
              }),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              side: WidgetStateProperty.all(
                BorderSide(color: colors.borderDefault),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
                ),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        AstraButtonVariant.ghost => TextButton(
            onPressed: _isDisabled ? null : onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              foregroundColor: colors.neutralGray,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        AstraButtonVariant.danger => FilledButton(
            onPressed: _isDisabled ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
              backgroundColor: colors.statusDanger,
              disabledBackgroundColor: colors.statusDanger.withValues(alpha: 0.5),
              foregroundColor: colors.textInverse,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
            ),
            child: _buildChild(labelStyle),
          ),
        },
      ),
    );
  }

  Color _labelColor(AstraColors colors) => switch (variant) {
        AstraButtonVariant.primary => colors.accentSecondary,
        AstraButtonVariant.secondary => colors.textPrimary,
        AstraButtonVariant.ghost => colors.neutralGray,
        AstraButtonVariant.danger => colors.textInverse,
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
