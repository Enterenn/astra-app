import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../formatters/step_count_formatter.dart';

/// Tappable row showing the current daily step goal with edit affordance.
class GoalEditorRow extends StatelessWidget {
  const GoalEditorRow({
    required this.dailyStepGoal,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final int dailyStepGoal;
  final VoidCallback? onTap;
  final bool enabled;

  bool get _isEnabled => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final formattedGoal = formatStepCount(dailyStepGoal);
    final valueColor =
        _isEnabled ? colors.textPrimary : colors.textMuted;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: _isEnabled
          ? 'Daily step goal, $formattedGoal. Double tap to edit.'
          : 'Daily step goal, $formattedGoal.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstraSpacing.kSpaceXs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily step goal',
                        style: AstraTypography.body(context),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceXs),
                      Text(
                        formattedGoal,
                        style: AstraTypography.headline(context).copyWith(
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _isEnabled ? colors.textSecondary : colors.textMuted,
                  semanticLabel: 'Edit daily step goal',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
