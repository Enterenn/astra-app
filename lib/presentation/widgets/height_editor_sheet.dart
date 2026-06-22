import 'package:astra_app/l10n/app_localizations.dart';
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

/// Opens a bottom sheet to edit height.
///
/// Returns saved height in cm, `-1` to clear, or `null` if cancelled.
Future<int?> showHeightEditorSheet(
  BuildContext context, {
  int? currentHeightCm,
  HeightDisplayUnit heightUnit = HeightDisplayUnit.cm,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _HeightEditorSheetBody(
      currentHeightCm: currentHeightCm,
      heightUnit: heightUnit,
    ),
  );
}

class _HeightEditorSheetBody extends StatefulWidget {
  const _HeightEditorSheetBody({
    this.currentHeightCm,
    required this.heightUnit,
  });

  final int? currentHeightCm;
  final HeightDisplayUnit heightUnit;

  @override
  State<_HeightEditorSheetBody> createState() => _HeightEditorSheetBodyState();
}

class _HeightEditorSheetBodyState extends State<_HeightEditorSheetBody> {
  late final TextEditingController _cmController;
  late final TextEditingController _feetController;
  late final TextEditingController _inchesController;
  String? _errorText;

  bool get _isFtIn => widget.heightUnit == HeightDisplayUnit.ftIn;

  String _ftInRangeMessage(AppLocalizations l10n) {
    final min = heightCmToFtIn(kMinHeightCm);
    final max = heightCmToFtIn(kMaxHeightCm);
    return l10n.profileHeightRangeFtIn(
      min.feet,
      min.inches,
      max.feet,
      max.inches,
    );
  }

  @override
  void initState() {
    super.initState();
    _cmController = TextEditingController(
      text: widget.currentHeightCm?.toString() ?? '',
    );
    final ftIn = widget.currentHeightCm == null
        ? null
        : heightCmToFtIn(widget.currentHeightCm!);
    _feetController = TextEditingController(
      text: ftIn?.feet.toString() ?? '',
    );
    _inchesController = TextEditingController(
      text: ftIn?.inches.toString() ?? '',
    );
    if (_isFtIn) {
      _feetController.addListener(_validateInput);
      _inchesController.addListener(_validateInput);
    } else {
      _cmController.addListener(_validateInput);
    }
  }

  @override
  void dispose() {
    _cmController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      _errorText = _validationMessage(AppLocalizations.of(context));
    });
  }

  String? _validationMessage(AppLocalizations l10n) {
    if (_isFtIn) {
      return _validationMessageFtIn(l10n);
    }
    return _validationMessageCm(l10n, _cmController.text);
  }

  String? _validationMessageCm(AppLocalizations l10n, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return l10n.profileHeightEnterWholeNumberCm;
    }
    if (parsed < kMinHeightCm || parsed > kMaxHeightCm) {
      return l10n.profileHeightRangeCm(kMinHeightCm, kMaxHeightCm);
    }
    return null;
  }

  String? _validationMessageFtIn(AppLocalizations l10n) {
    final feetRaw = _feetController.text.trim();
    final inchesRaw = _inchesController.text.trim();
    if (feetRaw.isEmpty && inchesRaw.isEmpty) {
      return null;
    }
    if (feetRaw.isEmpty || inchesRaw.isEmpty) {
      return l10n.profileHeightEnterBothFtIn;
    }
    final feet = int.tryParse(feetRaw);
    final inches = int.tryParse(inchesRaw);
    if (feet == null || inches == null) {
      return l10n.profileHeightEnterWholeNumbersFtIn;
    }
    if (inches < 0 || inches > 11) {
      return l10n.profileHeightInchesRange;
    }
    final heightCm = heightFtInToCm(feet: feet, inches: inches);
    if (heightCm == null) {
      return _ftInRangeMessage(l10n);
    }
    return null;
  }

  int? get _parsedHeightCm {
    if (_isFtIn) {
      final feetRaw = _feetController.text.trim();
      final inchesRaw = _inchesController.text.trim();
      if (feetRaw.isEmpty && inchesRaw.isEmpty) {
        return null;
      }
      final feet = int.tryParse(feetRaw);
      final inches = int.tryParse(inchesRaw);
      if (feet == null || inches == null) {
        return null;
      }
      return heightFtInToCm(feet: feet, inches: inches);
    }
    final trimmed = _cmController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  bool get _canSave {
    if (_errorText != null) {
      return false;
    }
    final parsed = _parsedHeightCm;
    return parsed != widget.currentHeightCm;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              Text(l10n.profileHeight, style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              if (_isFtIn) ...[
                TextField(
                  controller: _feetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: AstraTypography.bodyFor(colors).copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: profileSheetFieldDecoration(
                    colors: colors,
                    labelText: l10n.profileHeightFeet,
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                TextField(
                  controller: _inchesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AstraTypography.bodyFor(colors).copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: profileSheetFieldDecoration(
                    colors: colors,
                    labelText: l10n.profileHeightInches,
                    errorText: _errorText,
                  ),
                ),
              ] else
                TextField(
                  controller: _cmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: AstraTypography.bodyFor(colors).copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: profileSheetFieldDecoration(
                    colors: colors,
                    labelText: l10n.profileHeightCentimeters,
                    errorText: _errorText,
                  ),
                ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: l10n.commonSave,
                onPressed: _canSave
                    ? () {
                        final parsed = _parsedHeightCm;
                        Navigator.of(context).pop(parsed ?? -1);
                      }
                    : null,
              ),
              const SizedBox(height: AstraSpacing.kSpaceSm),
              AstraButton(
                label: l10n.commonCancel,
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
