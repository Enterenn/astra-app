import 'package:flutter/material.dart';

import 'astra_button.dart';

/// Secondary action button for My Data CSV import (UX-DR14 §2.5).
class DataImportButton extends StatelessWidget {
  const DataImportButton({
    required this.onPressed,
    required this.isLoading,
    this.label = 'Import CSV',
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Import CSV file',
      button: true,
      enabled: onPressed != null && !isLoading,
      child: AstraButton(
        label: label,
        variant: AstraButtonVariant.secondary,
        isLoading: isLoading,
        onPressed: onPressed,
      ),
    );
  }
}
