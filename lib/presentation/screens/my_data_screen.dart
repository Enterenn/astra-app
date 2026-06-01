import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

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
            Text('My Data', style: AstraTypography.title(context)),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            Text(
              'Data footprint, export, and settings will appear here.',
              style: AstraTypography.body(context),
            ),
          ],
        ),
      ),
    );
  }
}
