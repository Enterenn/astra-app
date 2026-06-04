import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../formatters/file_size_formatter.dart';

class FootprintKpiRow extends StatelessWidget {
  const FootprintKpiRow({
    required this.fileSizeBytes,
    super.key,
  });

  final int fileSizeBytes;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final sizeLabel = formatFileSize(fileSizeBytes);

    return Semantics(
      label: '$sizeLabel on your phone',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sizeLabel, style: AstraTypography.dataFor(colors)),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text('on your phone', style: AstraTypography.captionFor(colors)),
          ],
        ),
      ),
    );
  }
}
