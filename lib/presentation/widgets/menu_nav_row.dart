import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Tappable menu hub navigation row (label + chevron, no value sub-line).
class MenuNavRow extends StatelessWidget {
  static const double _kChevronSize = 16;

  const MenuNavRow({
    required this.label,
    required this.onTap,
    this.semanticsHint,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final hint = semanticsHint ?? l10n.commonDoubleTapToOpen;

    return Semantics(
      button: true,
      enabled: true,
      label: '$label. $hint',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstraSpacing.kSpaceSm,
              vertical: AstraSpacing.kSpaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: AstraTypography.body(context)),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: _kChevronSize,
                  color: colors.neutralGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
