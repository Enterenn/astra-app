import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Danger text action for My Data purge (UX §3.5 — filled danger only in dialog).
class DataPurgeButton extends StatelessWidget {
  const DataPurgeButton({
    required this.onPressed,
    required this.isLoading,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final label = l10n.myDataDeleteAllLocalData;
    final labelStyle = AstraTypography.labelFor(colors).copyWith(
      color: _isDisabled ? colors.textMuted : colors.statusDanger,
    );

    return Semantics(
      label: label,
      button: true,
      enabled: !_isDisabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AstraSpacing.kMinTouchTarget),
        child: TextButton(
          onPressed: _isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AstraSpacing.kMinTouchTarget),
            foregroundColor: colors.statusDanger,
            disabledForegroundColor: colors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
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
