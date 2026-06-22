import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Inline back arrow + gray screen title for secondary screens pushed from Menu.
class SecondaryScreenHeader extends StatelessWidget {
  const SecondaryScreenHeader({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    return Semantics(
      header: true,
      label: title,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.commonBack,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                PhosphorIconsRegular.arrowLeft,
                color: colors.textPrimary,
              ),
              tooltip: l10n.commonBack,
            ),
          ),
          const SizedBox(width: AstraSpacing.kSpaceXs),
          Expanded(
            child: Text(title, style: AstraTypography.screenTitleFor(colors)),
          ),
        ],
      ),
    );
  }
}
