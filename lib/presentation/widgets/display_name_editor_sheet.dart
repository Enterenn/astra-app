import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import 'astra_button.dart';
import 'profile_sheet_field_decoration.dart';

/// Opens a bottom sheet to edit the local display name.
///
/// Returns the trimmed name, empty string to clear, or `null` if cancelled.
Future<String?> showDisplayNameEditorSheet(
  BuildContext context, {
  String? currentName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _DisplayNameEditorSheetBody(currentName: currentName),
  );
}

class _DisplayNameEditorSheetBody extends StatefulWidget {
  const _DisplayNameEditorSheetBody({this.currentName});

  final String? currentName;

  @override
  State<_DisplayNameEditorSheetBody> createState() =>
      _DisplayNameEditorSheetBodyState();
}

class _DisplayNameEditorSheetBodyState extends State<_DisplayNameEditorSheetBody> {
  late final TextEditingController _controller;
  late String _input;

  @override
  void initState() {
    super.initState();
    _input = widget.currentName ?? '';
    _controller = TextEditingController(text: _input);
    _controller.addListener(() => setState(() => _input = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _input.trim();

  bool get _canSave {
    final trimmed = _trimmed;
    final current = widget.currentName?.trim();
    if (trimmed.isEmpty && (current == null || current.isEmpty)) {
      return false;
    }
    return trimmed != current;
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
              Text(l10n.profileDisplayName, style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              TextField(
                controller: _controller,
                maxLength: kMaxDisplayNameLength,
                autofocus: true,
                style: AstraTypography.bodyFor(colors).copyWith(
                  color: colors.textPrimary,
                ),
                decoration: profileSheetFieldDecoration(
                  colors: colors,
                  labelText: l10n.profileDisplayNameFirstName,
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: l10n.commonSave,
                onPressed: _canSave
                    ? () => Navigator.of(context).pop(_trimmed)
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
