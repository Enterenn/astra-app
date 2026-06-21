import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Single-line settings row: label left, value + chevron right (Story 10.6).
class SettingsPreferenceRow extends StatelessWidget {
  const SettingsPreferenceRow({
    required this.label,
    required this.valueLabel,
    required this.onTap,
    super.key,
  });

  final String label;
  final String valueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    return Semantics(
      button: true,
      label: '$label, $valueLabel. ${l10n.commonDoubleTapToChange}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AstraSpacing.kSpaceXs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: AstraTypography.body(context)),
                  ),
                  Text(
                    valueLabel,
                    style: AstraTypography.body(context).copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AstraSpacing.kSpaceXs),
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    color: colors.neutralGray,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
