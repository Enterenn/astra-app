import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Accent-outline action button for My Data export/import flows (UX-DR14).
class DataExportButton extends StatelessWidget {
  const DataExportButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String semanticsLabel;

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
      color: _isDisabled ? colors.textMuted : colors.textPrimary,
    );

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: !_isDisabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AstraSpacing.kMinTouchTarget),
        child: OutlinedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(
              const Size.fromHeight(AstraSpacing.kMinTouchTarget),
            ),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (_isDisabled) {
                return colors.textMuted;
              }
              if (_isInteractive(states)) {
                return colors.accentSecondary;
              }
              return colors.textPrimary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (_isDisabled) {
                return Colors.transparent;
              }
              if (_isInteractive(states)) {
                return colors.accentPrimary;
              }
              return Colors.transparent;
            }),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: _isDisabled ? colors.borderDefault : colors.accentPrimary,
              ),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              ),
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
              : Text(label, style: labelStyle),
        ),
      ),
    );
  }
}
