import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/validation/step_goal_validator.dart';
import 'astra_button.dart';

/// Opens a bottom sheet to edit the daily step goal.
///
/// Returns the saved goal, or `null` if cancelled or dismissed.
Future<int?> showGoalEditorSheet(
  BuildContext context, {
  required int currentGoal,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _GoalEditorSheetBody(currentGoal: currentGoal),
  );
}

class _GoalEditorSheetBody extends StatefulWidget {
  const _GoalEditorSheetBody({required this.currentGoal});

  final int currentGoal;

  @override
  State<_GoalEditorSheetBody> createState() => _GoalEditorSheetBodyState();
}

class _GoalEditorSheetBodyState extends State<_GoalEditorSheetBody> {
  late final TextEditingController _controller;
  late String _input;

  @override
  void initState() {
    super.initState();
    _input = widget.currentGoal.toString();
    _controller = TextEditingController(text: _input);
    _controller.addListener(() => setState(() => _input = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  StepGoalValidationResult get _validation => validateStepGoalInput(_input);

  bool get _canSave {
    if (!_validation.isValid || _validation.parsedGoal == null) {
      return false;
    }
    return _validation.parsedGoal != widget.currentGoal;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final validation = _validation;

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
              Text('Daily step goal', style: AstraTypography.title(context)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
                    borderSide: BorderSide(color: colors.borderDefault),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
                    borderSide: BorderSide(color: colors.borderDefault),
                  ),
                  errorText: validation.isValid ? null : validation.errorMessage,
                ),
              ),
              const SizedBox(height: AstraSpacing.kSpaceLg),
              AstraButton(
                label: 'Save',
                onPressed: _canSave
                    ? () => Navigator.of(context).pop(_validation.parsedGoal)
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
