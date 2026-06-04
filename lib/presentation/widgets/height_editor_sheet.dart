import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import 'astra_button.dart';
import 'profile_sheet_field_decoration.dart';

/// Opens a bottom sheet to edit height in centimeters.
///
/// Returns saved height in cm, `-1` to clear, or `null` if cancelled.
Future<int?> showHeightEditorSheet(
  BuildContext context, {
  int? currentHeightCm,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _HeightEditorSheetBody(currentHeightCm: currentHeightCm),
  );
}

class _HeightEditorSheetBody extends StatefulWidget {
  const _HeightEditorSheetBody({this.currentHeightCm});

  final int? currentHeightCm;

  @override
  State<_HeightEditorSheetBody> createState() => _HeightEditorSheetBodyState();
}

class _HeightEditorSheetBodyState extends State<_HeightEditorSheetBody> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentHeightCm?.toString() ?? '',
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
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a whole number in centimeters';
    }
    if (parsed < kMinHeightCm || parsed > kMaxHeightCm) {
      return 'Height must be between $kMinHeightCm and $kMaxHeightCm cm';
    }
    return null;
  }

  int? get _parsedHeight {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  bool get _canSave {
    if (_errorText != null) {
      return false;
    }
    final parsed = _parsedHeight;
    return parsed != widget.currentHeightCm;
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
              Text('Height', style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: AstraTypography.bodyFor(colors).copyWith(
                  color: colors.textPrimary,
                ),
                decoration: profileSheetFieldDecoration(
                  colors: colors,
                  labelText: 'Centimeters',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: 'Save',
                onPressed: _canSave
                    ? () {
                        final parsed = _parsedHeight;
                        Navigator.of(context).pop(parsed ?? -1);
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
