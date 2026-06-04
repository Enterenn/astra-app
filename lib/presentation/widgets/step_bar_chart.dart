import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../data/models/chart_day_aggregate.dart';
import '../cubits/history_state.dart';

class StepBarChart extends StatelessWidget {
  const StepBarChart({
    required this.points,
    required this.dailyGoal,
    required this.status,
    super.key,
  });

  static const emptyCopy =
      'No history yet. Walk a bit — data stays on this device.';

  final List<ChartDayAggregate> points;
  final int dailyGoal;
  final HistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Semantics(
      label: 'Step history bar chart',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.bgSubtle,
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
            child: switch (status) {
              HistoryStatus.loading => _LoadingSkeleton(colors: colors),
              HistoryStatus.empty => _EmptyState(colors: colors),
              HistoryStatus.ready => _ReadyChart(
                points: points,
                dailyGoal: dailyGoal,
                colors: colors,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kSpaceLg),
        child: Text(
          StepBarChart.emptyCopy,
          style: AstraTypography.bodyFor(colors).copyWith(
            color: colors.neutralGray,
          ),
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

class _ReadyChart extends StatelessWidget {
  const _ReadyChart({
    required this.points,
    required this.dailyGoal,
    required this.colors,
  });

  final List<ChartDayAggregate> points;
  final int dailyGoal;
  final AstraColors colors;

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final maxSteps = points.fold<int>(
      0,
      (max, entry) => entry.totalSteps > max ? entry.totalSteps : max,
    );
    final yMax = (maxSteps > dailyGoal ? maxSteps : dailyGoal).toDouble();
    final safeYMax = (yMax <= 0
            ? dailyGoal.toDouble().clamp(1, double.infinity)
            : yMax)
        .toDouble();
    final chartMaxY = safeYMax * 1.05;

    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AstraSpacing.kSpaceSm,
          AstraSpacing.kSpaceMd,
          AstraSpacing.kSpaceMd,
          AstraSpacing.kSpaceSm,
        ),
        child: BarChart(
          duration: Duration.zero,
          BarChartData(
            maxY: chartMaxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: const BarTouchData(enabled: false),
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
                  reservedSize: 36,
                  interval: chartMaxY,
                  getTitlesWidget: (value, meta) {
                    if (value.abs() < 0.01) {
                      return Text(
                        '0',
                        style: AstraTypography.captionFor(colors).copyWith(
                          color: colors.textMuted,
                        ),
                      );
                    }
                    if ((value - chartMaxY).abs() < chartMaxY * 0.001) {
                      return Text(
                        _formatAxisValue(safeYMax.round()),
                        style: AstraTypography.captionFor(colors).copyWith(
                          color: colors.textMuted,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    if (points.length > 7 &&
                        !_shouldShowBottomLabel(index, points.length)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: AstraSpacing.kSpaceXs),
                      child: Text(
                        _formatDayLabel(points[index].localDay),
                        style: AstraTypography.captionFor(colors).copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: dailyGoal.toDouble(),
                  color: colors.dataGoalLine,
                  strokeWidth: 1.5,
                  dashArray: const [6, 4],
                ),
              ],
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].totalSteps.toDouble(),
                      color: colors.dataPositive,
                      width: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _shouldShowBottomLabel(int index, int pointCount) {
    if (pointCount <= 7) {
      return true;
    }
    final step = (pointCount / 6).ceil().clamp(1, pointCount);
    return index % step == 0 || index == pointCount - 1;
  }

  String _formatDayLabel(DateTime localDay) {
    if (points.length <= 7) {
      return _weekdayLabels[localDay.weekday - 1];
    }
    return '${localDay.day}/${localDay.month}';
  }

  String _formatAxisValue(int value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      return thousands == thousands.roundToDouble()
          ? '${thousands.toInt()}k'
          : '${thousands.toStringAsFixed(1)}k';
    }
    return '$value';
  }
}
