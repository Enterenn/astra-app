import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../l10n/l10n_date_labels.dart';
import '../models/week_day_status.dart';

/// Seven day pills for the current calendar week (Mon–Sun).
class WeekProgressRow extends StatelessWidget {
  const WeekProgressRow({
    required this.days,
    required this.selectedLocalDay,
    required this.onDayTap,
    super.key,
  });

  final List<WeekDayStatus> days;
  final DateTime selectedLocalDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: AstraSpacing.kSpaceXs),
          Expanded(
            child: _DayPill(
              day: days[i],
              isSelected: _isSameLocalDay(days[i].localDay, selectedLocalDay),
              onTap: days[i].isFuture
                  ? null
                  : () => onDayTap(days[i].localDay),
            ),
          ),
        ],
      ],
    );
  }
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final WeekDayStatus day;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final l10n = AppLocalizations.of(context);
    final isToday = day.isToday;
    final selected = isSelected;

    final backgroundColor =
        selected ? colors.accentPrimary : colors.bgSubtle;
    final dayNumberColor =
        day.isFuture ? colors.neutralGray : colors.textPrimary;
    final mutedColor = selected ? colors.accentSecondary : colors.neutralGray;

    Color? dotColor;
    if (selected || isToday || day.isFuture) {
      dotColor = null;
    } else if (day.goalMet) {
      dotColor = colors.accentPrimary;
    }

    final weekdayLabel = l10n.weekdayPillLabel(day.localDay);

    return Semantics(
      label: l10n.todayWeekDaySemantics(weekdayLabel, day.dayNumber),
      selected: selected,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
          onTap: onTap,
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
                  weekdayLabel,
                  style: AstraTypography.captionFor(colors).copyWith(
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${day.dayNumber}',
                  style: AstraTypography.labelFor(colors).copyWith(
                    color: dayNumberColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
