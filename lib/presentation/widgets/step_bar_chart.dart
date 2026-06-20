import 'package:astra_app/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import '../../core/time/local_day_formatter.dart';
import '../../data/models/chart_day_aggregate.dart';
import '../cubits/history_state.dart';
import '../l10n/l10n_date_labels.dart';
import 'chart/astra_bar_chart_touch.dart';
import 'chart/chart_axis_ticks.dart';
import 'chart/goal_step_line_painter.dart';

class StepBarChart extends StatelessWidget {
  const StepBarChart({
    required this.points,
    required this.dailyGoal,
    required this.goalsByDay,
    required this.status,
    super.key,
  });

  static const kDailyChartHeight = 320.0;

  final List<ChartDayAggregate> points;
  final int dailyGoal;
  final Map<String, int> goalsByDay;
  final HistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final chartShell = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kDailyChartHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
          child: switch (status) {
            HistoryStatus.loading => _LoadingSkeleton(colors: colors),
            HistoryStatus.empty => _EmptyState(colors: colors, l10n: l10n),
            HistoryStatus.ready => _ReadyChart(
              points: points,
              dailyGoal: dailyGoal,
              goalsByDay: goalsByDay,
              colors: colors,
            ),
          },
        ),
      ),
    );

    if (status == HistoryStatus.ready) {
      return chartShell;
    }

    return Semantics(
      label: l10n.trendsStepBarChartSemantics,
      child: chartShell,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.l10n});

  final AstraColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kSpaceLg),
        child: Text(
          l10n.trendsEmptyHistory,
          style: AstraTypography.bodyFor(
            colors,
          ).copyWith(color: colors.neutralGray),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.colors});

  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AstraSpacing.kSpaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AstraSpacing.kSpaceXs,
                ),
                child: Container(
                  height: 48 + (i % 3) * 24,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadyChart extends StatefulWidget {
  const _ReadyChart({
    required this.points,
    required this.dailyGoal,
    required this.goalsByDay,
    required this.colors,
  });

  final List<ChartDayAggregate> points;
  final int dailyGoal;
  final Map<String, int> goalsByDay;
  final AstraColors colors;

  @override
  State<_ReadyChart> createState() => _ReadyChartState();
}

class _ReadyChartState extends State<_ReadyChart> {
  static const _kBelowGoalBarAlpha = 0.66;
  static const _kSelectedBarAlpha = 0.8;
  static const _kMaxBarWidth = 12.0;
  static const _kMinBarWidth = 4.0;
  static const _kBarSlotFillRatio = 0.55;
  static const _kLeftAxisReserved = 36.0;
  static const _kBottomAxisReserved = 24.0;

  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = widget.colors;
    final points = widget.points;
    final resolvedGoals = [for (final point in points) _goalForPoint(point)];
    final maxSteps = points.fold<int>(
      0,
      (max, entry) => entry.totalSteps > max ? entry.totalSteps : max,
    );
    final maxGoal = resolvedGoals.isEmpty
        ? widget.dailyGoal
        : resolvedGoals.reduce((a, b) => a > b ? a : b);
    final yMax = (maxSteps > maxGoal ? maxSteps : maxGoal).toDouble();
    final safeYMax =
        (yMax <= 0
                ? widget.dailyGoal.toDouble().clamp(1, double.infinity)
                : yMax)
            .toDouble();
    final chartMaxY = safeYMax * 1.05;
    final allGoalsEqual =
        resolvedGoals.isNotEmpty &&
        resolvedGoals.every((goal) => goal == resolvedGoals.first);
    final showSingleGoalLine = allGoalsEqual && resolvedGoals.first > 0;
    final showSteppedGoalLine =
        !allGoalsEqual && resolvedGoals.any((goal) => goal > 0);
    final axisReferenceGoal = resolvedGoals.isEmpty
        ? null
        : allGoalsEqual
        ? resolvedGoals.first
        : mostCommonChartReferenceValue(resolvedGoals);
    final yTicks = computeChartYAxisTicks(
      maxY: chartMaxY,
      referenceValues: axisReferenceGoal == null
          ? const []
          : [axisReferenceGoal],
    );
    final yAxisInterval = chartAxisTitleInterval(yTicks);

    final semanticsLabel = _touchedIndex == null
        ? l10n.trendsStepBarChartSemantics
        : _selectionSemanticsLabel(
            l10n: l10n,
            point: points[_touchedIndex!],
            goal: resolvedGoals[_touchedIndex!],
          );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstraSpacing.kSpaceSm,
            AstraSpacing.kSpaceMd,
            AstraSpacing.kSpaceMd,
            AstraSpacing.kSpaceSm,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = _resolveBarWidth(
                constraints.maxWidth,
                points.length,
              );
              final barGroups = [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].totalSteps.toDouble(),
                        color: _barColor(
                          colors: colors,
                          steps: points[i].totalSteps,
                          dailyGoal: resolvedGoals[i],
                          isSelected: _touchedIndex == i,
                        ),
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ];

              final chartHeight =
                  constraints.maxHeight.isFinite && constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : StepBarChart.kDailyChartHeight;

              return SizedBox(
                height: chartHeight,
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    BarChart(
                      duration: Duration.zero,
                      BarChartData(
                        maxY: chartMaxY,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: buildAstraBarTouchData(
                          colors: colors,
                          touchedIndex: _touchedIndex,
                          onTouchedIndexChanged: (index) {
                            setState(() => _touchedIndex = index);
                          },
                          tooltipData: buildAstraBarTooltipData(
                            colors: colors,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return _dailyTooltipItem(
                                l10n: l10n,
                                colors: colors,
                                point: points[groupIndex],
                                goal: resolvedGoals[groupIndex],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: _kLeftAxisReserved,
                              interval: yAxisInterval,
                              getTitlesWidget: (value, meta) {
                                for (final tick in yTicks) {
                                  if (!isChartAxisTickLabel(
                                    value: value,
                                    tick: tick,
                                    ticks: yTicks,
                                  )) {
                                    continue;
                                  }
                                  return Text(
                                    formatChartAxisValue(tick.round()),
                                    style: AstraTypography.captionFor(
                                      colors,
                                    ).copyWith(color: colors.textPrimary),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: _kBottomAxisReserved,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                if (points.length > 7 &&
                                    !_shouldShowBottomLabel(
                                      index,
                                      points.length,
                                    )) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AstraSpacing.kSpaceXs,
                                  ),
                                  child: Text(
                                    _formatDayLabel(
                                      l10n,
                                      points[index].localDay,
                                    ),
                                    style: AstraTypography.captionFor(
                                      colors,
                                    ).copyWith(color: colors.textPrimary),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: showSingleGoalLine
                              ? [
                                  HorizontalLine(
                                    y: resolvedGoals.first.toDouble(),
                                    color: colors.dataGoalLine,
                                    strokeWidth: 1.5,
                                    dashArray: const [6, 4],
                                  ),
                                ]
                              : const [],
                        ),
                        barGroups: withBarTouchIndicators(
                          groups: barGroups,
                          touchedIndex: _touchedIndex,
                        ),
                      ),
                    ),
                    if (showSteppedGoalLine)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: GoalStepLinePainter(
                              goals: resolvedGoals,
                              maxY: chartMaxY,
                              barCount: points.length,
                              barWidth: barWidth,
                              color: colors.dataGoalLine,
                              leftReserved: _kLeftAxisReserved,
                              bottomReserved: _kBottomAxisReserved,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _goalForPoint(ChartDayAggregate point) {
    return widget.goalsByDay[localDayIsoFromDateOnly(point.localDay)] ??
        kDefaultStepGoal;
  }

  BarTooltipItem _dailyTooltipItem({
    required AppLocalizations l10n,
    required AstraColors colors,
    required ChartDayAggregate point,
    required int goal,
  }) {
    final steps = point.totalSteps;

    return BarTooltipItem(
      '${_formatTooltipDate(l10n, point.localDay)}\n'
      '${l10n.chartTooltipStepsOfGoal(steps, goal)}',
      astraBarTooltipPrimaryStyle(colors),
    );
  }

  String _selectionSemanticsLabel({
    required AppLocalizations l10n,
    required ChartDayAggregate point,
    required int goal,
  }) {
    final steps = point.totalSteps;
    return l10n.chartSelectionSemantics(
      _formatTooltipDate(l10n, point.localDay),
      steps,
      goal,
      l10n.chartGoalStatus(steps: steps, goal: goal),
    );
  }

  String _formatTooltipDate(AppLocalizations l10n, DateTime localDay) {
    return l10n.formatChartTooltipDate(
      localDay,
      includeYear: _chartSpansMultipleYears,
    );
  }

  bool get _chartSpansMultipleYears {
    final points = widget.points;
    if (points.length < 2) {
      return false;
    }
    return points.first.localDay.year != points.last.localDay.year;
  }

  static double _resolveBarWidth(double chartWidth, int pointCount) {
    if (pointCount <= 0 || chartWidth <= 0) {
      return _kMaxBarWidth;
    }
    final slotWidth = chartWidth / pointCount;
    return (slotWidth * _kBarSlotFillRatio).clamp(_kMinBarWidth, _kMaxBarWidth);
  }

  static Color _barColor({
    required AstraColors colors,
    required int steps,
    required int dailyGoal,
    required bool isSelected,
  }) {
    if (isSelected) {
      return colors.accentPrimary.withValues(alpha: _kSelectedBarAlpha);
    }
    if (dailyGoal > 0 && steps >= dailyGoal) {
      return colors.dataPositive;
    }
    return colors.accentPrimary.withValues(alpha: _kBelowGoalBarAlpha);
  }

  static bool _shouldShowBottomLabel(int index, int pointCount) {
    if (pointCount <= 7) {
      return true;
    }
    final step = (pointCount / 6).ceil().clamp(1, pointCount);
    return index % step == 0 || index == pointCount - 1;
  }

  String _formatDayLabel(AppLocalizations l10n, DateTime localDay) {
    if (widget.points.length <= 7) {
      return l10n.weekdayShort(localDay);
    }
    return '${localDay.day}/${localDay.month}';
  }
}
