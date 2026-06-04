import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../models/week_day_status.dart';

/// Seven day pills for the current calendar week (Mon–Sun).
class WeekProgressRow extends StatelessWidget {
  const WeekProgressRow({required this.days, super.key});

  final List<WeekDayStatus> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: AstraSpacing.kSpaceXs),
          Expanded(child: _DayPill(day: days[i])),
        ],
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day});

  final WeekDayStatus day;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final isToday = day.isToday;

    final backgroundColor =
        isToday ? colors.accentPrimary : colors.bgSubtle;
    final textColor = isToday ? colors.accentSecondary : colors.textPrimary;
    final mutedColor = isToday ? colors.accentSecondary : colors.neutralGray;

    Color? dotColor;
    if (isToday) {
      dotColor = null;
    } else if (day.isFuture) {
      dotColor = colors.neutralGray;
    } else if (day.goalMet) {
      dotColor = colors.accentPrimary;
    }

    return Semantics(
      label: '${day.weekdayLabel} ${day.dayNumber}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AstraSpacing.kSpaceSm),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 8,
              child: Center(
                child: dotColor != null
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox(width: 6, height: 6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day.weekdayLabel,
              style: AstraTypography.captionFor(colors).copyWith(
                color: mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.dayNumber}',
              style: AstraTypography.labelFor(colors).copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
