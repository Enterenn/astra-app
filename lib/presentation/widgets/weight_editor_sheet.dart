import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import 'astra_button.dart';
import 'profile_sheet_field_decoration.dart';

/// Opens a bottom sheet to edit weight in kilograms.
///
/// Returns saved weight in kg, `-1.0` to clear, or `null` if cancelled.
Future<double?> showWeightEditorSheet(
  BuildContext context, {
  double? currentWeightKg,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _WeightEditorSheetBody(currentWeightKg: currentWeightKg),
  );
}

class _WeightEditorSheetBody extends StatefulWidget {
  const _WeightEditorSheetBody({this.currentWeightKg});

  final double? currentWeightKg;

  @override
  State<_WeightEditorSheetBody> createState() => _WeightEditorSheetBodyState();
}

class _WeightEditorSheetBodyState extends State<_WeightEditorSheetBody> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.currentWeightKg;
    _controller = TextEditingController(
      text: initial == null
          ? ''
          : (initial == initial.roundToDouble()
                ? initial.toInt().toString()
                : initial.toStringAsFixed(1)),
    );
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      _errorText = _validationMessage(_controller.text);
    });
  }

  String? _validationMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Enter a valid weight';
    }
    final rounded = (parsed * 10).round() / 10;
    if (rounded < kMinWeightKg || rounded > kMaxWeightKg) {
      return 'Weight must be between ${kMinWeightKg.toInt()} and ${kMaxWeightKg.toInt()} kg';
    }
    final decimalPart = trimmed.contains('.') || trimmed.contains(',');
    if (decimalPart) {
      final parts = trimmed.replaceAll(',', '.').split('.');
      if (parts.length > 1 && parts[1].length > 1) {
        return 'Use at most one decimal place';
      }
    }
    return null;
  }

  double? get _parsedWeight {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return null;
    }
    return (parsed * 10).round() / 10;
  }

  bool get _canSave {
    if (_errorText != null) {
      return false;
    }
    final parsed = _parsedWeight;
    return parsed != widget.currentWeightKg;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstraSpacing.kScreenHorizontalPadding,
            AstraSpacing.kSpaceSm,
            AstraSpacing.kScreenHorizontalPadding,
            AstraSpacing.kSpaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              Text('Weight', style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                autofocus: true,
                style: AstraTypography.bodyFor(colors).copyWith(
                  color: colors.textPrimary,
                ),
                decoration: profileSheetFieldDecoration(
                  colors: colors,
                  labelText: 'Kilograms',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: 'Save',
                onPressed: _canSave
                    ? () {
                        final parsed = _parsedWeight;
                        Navigator.of(context).pop(parsed ?? -1.0);
                      }
                    : null,
              ),
              const SizedBox(height: AstraSpacing.kSpaceSm),
              AstraButton(
                label: 'Cancel',
                variant: AstraButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
