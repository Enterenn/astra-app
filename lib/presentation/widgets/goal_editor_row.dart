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
    super.key,
  });

  final int dailyStepGoal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final formattedGoal = formatStepCount(dailyStepGoal);

    return Semantics(
      button: true,
      label: 'Daily step goal, $formattedGoal. Double tap to edit.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
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
