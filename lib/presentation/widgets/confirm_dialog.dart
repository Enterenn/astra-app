import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_button.dart';

/// Result of the purge confirmation dialog (FR-21).
enum PurgeConfirmAction {
  cancelled,
  exportFirst,
  deleteConfirmed,
}

/// Purge confirmation with export-first nudge (UX §3.11, FR-21).
///
/// **Export first** invokes [onExportFirst] without closing the dialog.
/// The future completes only when the user taps **Cancel** or **Delete anyway**.
Future<PurgeConfirmAction?> showPurgeConfirmDialog(
  BuildContext context, {
  required VoidCallback onExportFirst,
}) async {
  final result = await showDialog<PurgeConfirmAction>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.astraColors;
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          'Delete all local data?',
          style: AstraTypography.title(dialogContext),
        ),
        content: Text(
          'This removes all step history on this device. '
          'Export first if you want to keep a copy.',
          style: AstraTypography.body(dialogContext),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AstraSpacing.kSpaceMd,
          0,
          AstraSpacing.kSpaceMd,
          AstraSpacing.kSpaceMd,
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AstraButton(
                      label: 'Export first',
                      variant: AstraButtonVariant.secondary,
                      onPressed: onExportFirst,
                    ),
                  ),
                  const SizedBox(width: AstraSpacing.kSpaceSm),
                  Expanded(
                    child: AstraButton(
                      label: 'Delete anyway',
                      variant: AstraButtonVariant.danger,
                      onPressed: () => Navigator.of(dialogContext).pop(
                        PurgeConfirmAction.deleteConfirmed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AstraSpacing.kSpaceSm),
              AstraButton(
                label: 'Cancel',
                variant: AstraButtonVariant.ghost,
                onPressed: () => Navigator.of(dialogContext).pop(
                  PurgeConfirmAction.cancelled,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result;
}

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
