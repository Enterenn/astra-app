import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Menu hub placeholder until Story 10.2 adds list rows and navigation.
class MenuHubScreen extends StatelessWidget {
  const MenuHubScreen({super.key});

  static const _kScreenTitle = 'Menu';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstraSpacing.kScreenHorizontalPadding,
            AstraSpacing.kSpaceSm,
            AstraSpacing.kScreenHorizontalPadding,
            0,
          ),
          child: Text(
            _kScreenTitle,
            style: AstraTypography.screenTitleFor(colors),
          ),
        ),
      ),
    );
  }
}
