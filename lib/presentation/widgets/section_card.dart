import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'elevated_card.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.headline,
    required this.child,
    this.padding = AstraSpacing.kCardPadding,
    super.key,
  });

  final String headline;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: AstraTypography.headline(context)),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          child,
        ],
      ),
    );
  }
}
