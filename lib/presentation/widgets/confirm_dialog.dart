import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_button.dart';

/// Import confirmation before merging CSV into a non-empty database (UX-DR15).
Future<bool> showImportConfirmDialog(
  BuildContext context, {
  required int csvRowCount,
  required int existingSampleCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.astraColors;
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text('Import data?', style: AstraTypography.title(dialogContext)),
        content: Text(
          'This file contains $csvRowCount samples. '
          'Your database already has $existingSampleCount samples. '
          'Rows with matching IDs or the same time bucket will be skipped — '
          'existing data is not overwritten.',
          style: AstraTypography.body(dialogContext),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AstraSpacing.kSpaceMd,
          0,
          AstraSpacing.kSpaceMd,
          AstraSpacing.kSpaceMd,
        ),
        actions: [
          AstraButton(
            label: 'Cancel',
            variant: AstraButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AstraButton(
            label: 'Import',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
