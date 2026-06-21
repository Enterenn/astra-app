import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Tappable profile field row (label, value, chevron).
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    required this.label,
    required this.valueLabel,
    required this.onTap,
    this.enabled = true,
    this.semanticsHint,
    super.key,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticsHint;

  bool get _isEnabled => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final valueColor =
        _isEnabled ? colors.textPrimary : colors.textMuted;
    final editHint = semanticsHint ?? l10n.commonDoubleTapToEdit;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: _isEnabled
          ? '$label, $valueLabel. $editHint'
          : '$label, $valueLabel.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstraSpacing.kSpaceXs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AstraTypography.body(context)),
                      const SizedBox(height: AstraSpacing.kSpaceXs),
                      Text(
                        valueLabel,
                        style: AstraTypography.headline(context).copyWith(
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  color: _isEnabled ? colors.neutralGray : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
