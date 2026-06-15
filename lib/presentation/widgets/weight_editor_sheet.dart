import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
import '../formatters/display_unit_formatter.dart';
import 'astra_button.dart';
import 'profile_sheet_field_decoration.dart';

/// Opens a bottom sheet to edit weight.
///
/// Returns saved weight in kg, `-1.0` to clear, or `null` if cancelled.
Future<double?> showWeightEditorSheet(
  BuildContext context, {
  double? currentWeightKg,
  WeightDisplayUnit weightUnit = WeightDisplayUnit.kg,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _WeightEditorSheetBody(
      currentWeightKg: currentWeightKg,
      weightUnit: weightUnit,
    ),
  );
}

class _WeightEditorSheetBody extends StatefulWidget {
  const _WeightEditorSheetBody({
    this.currentWeightKg,
    required this.weightUnit,
  });

  final double? currentWeightKg;
  final WeightDisplayUnit weightUnit;

  @override
  State<_WeightEditorSheetBody> createState() => _WeightEditorSheetBodyState();
}

class _WeightEditorSheetBodyState extends State<_WeightEditorSheetBody> {
  late final TextEditingController _controller;
  String? _errorText;

  bool get _isLb => widget.weightUnit == WeightDisplayUnit.lb;

  double get _minDisplay => _isLb ? weightKgToDisplayLb(kMinWeightKg) : kMinWeightKg;

  double get _maxDisplay => _isLb ? weightKgToDisplayLb(kMaxWeightKg) : kMaxWeightKg;

  @override
  void initState() {
    super.initState();
    final initial = widget.currentWeightKg;
    _controller = TextEditingController(
      text: _initialText(initial),
    );
    _controller.addListener(_validateInput);
  }

  String _initialText(double? weightKg) {
    if (weightKg == null) {
      return '';
    }
    if (_isLb) {
      final lb = weightKgToDisplayLb(weightKg);
      if (lb == lb.roundToDouble()) {
        return lb.toInt().toString();
      }
      return lb.toStringAsFixed(1);
    }
    if (weightKg == weightKg.roundToDouble()) {
      return weightKg.toInt().toString();
    }
    return weightKg.toStringAsFixed(1);
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
    if (rounded < _minDisplay || rounded > _maxDisplay) {
      if (_isLb) {
        return 'Weight must be between ${_minDisplay.toStringAsFixed(1)} and ${_maxDisplay.toStringAsFixed(1)} lb';
      }
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

  double? get _parsedWeightKg {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return null;
    }
    final rounded = (parsed * 10).round() / 10;
    if (_isLb) {
      return displayLbToWeightKg(rounded);
    }
    return rounded;
  }

  bool get _canSave {
    if (_errorText != null) {
      return false;
    }
    final parsed = _parsedWeightKg;
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
                  labelText: _isLb ? 'Pounds' : 'Kilograms',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: 'Save',
                onPressed: _canSave
                    ? () {
                        final parsed = _parsedWeightKg;
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
