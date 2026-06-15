import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
    final colors = context.astraColors;

    return Semantics(
      header: true,
      label: title,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                PhosphorIconsRegular.arrowLeft,
                color: colors.textPrimary,
              ),
              tooltip: 'Back',
            ),
          ),
          const SizedBox(width: AstraSpacing.kSpaceXs),
          Text(title, style: AstraTypography.screenTitleFor(colors)),
        ],
      ),
    );
  }
}
