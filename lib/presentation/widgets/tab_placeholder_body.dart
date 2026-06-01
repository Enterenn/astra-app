import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Shared layout for Phase 0 tab placeholder screens (Story 1.3).
class TabPlaceholderBody extends StatelessWidget {
  const TabPlaceholderBody({
    required this.title,
    required this.placeholder,
    super.key,
  });

  final String title;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AstraSpacing.kScreenHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              Text(placeholder, style: AstraTypography.body(context)),
            ],
          ),
        ),
      ),
    );
  }
}
