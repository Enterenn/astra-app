import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AstraSpacing.kScreenHorizontalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: AstraTypography.title(context)),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            Text(
              'Step tracking and your goal ring will appear here.',
              style: AstraTypography.body(context),
            ),
          ],
        ),
      ),
    );
  }
}
