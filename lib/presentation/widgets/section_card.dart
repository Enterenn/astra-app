import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'elevated_card.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.headline,
    required this.child,
    this.trailing,
    this.padding = AstraSpacing.kCardPadding,
    super.key,
  });

  final String headline;
  final Widget? trailing;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(headline, style: AstraTypography.headline(context)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          child,
        ],
      ),
    );
  }
}
