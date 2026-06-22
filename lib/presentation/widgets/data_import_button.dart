import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'astra_button.dart';

/// Secondary action button for My Data CSV import (UX-DR14 §2.5).
class DataImportButton extends StatelessWidget {
  const DataImportButton({
    required this.onPressed,
    required this.isLoading,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.myDataImportCsvSemantics,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: AstraButton(
        label: l10n.myDataImportCsv,
        variant: AstraButtonVariant.secondary,
        isLoading: isLoading,
        onPressed: onPressed,
      ),
    );
  }
}
