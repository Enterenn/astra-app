import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import 'secondary_screen_header.dart';

/// Shared layout for secondary screens pushed from the Menu tab.
class SecondaryScreenShell extends StatelessWidget {
  const SecondaryScreenShell({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding - AstraSpacing.kIconButtonHorizontalInset,
                AstraSpacing.kSpaceSm,
                horizontalPadding,
                0,
              ),
              child: SecondaryScreenHeader(title: title),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
