import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
            Text('History', style: AstraTypography.title(context)),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            Text(
              'Your 7-day and 30-day charts will appear here.',
              style: AstraTypography.body(context),
            ),
          ],
        ),
      ),
    );
  }
}
