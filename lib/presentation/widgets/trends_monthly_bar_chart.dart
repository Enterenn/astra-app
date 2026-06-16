import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../data/models/chart_month_aggregate.dart';
import '../cubits/history_state.dart';
import 'step_bar_chart.dart';

/// Twelve-month monthly average steps chart for the Trends screen.
class TrendsMonthlyBarChart extends StatelessWidget {
  const TrendsMonthlyBarChart({
    required this.points,
    required this.status,
    super.key,
  });

  final List<ChartMonthAggregate> points;
  final HistoryStatus status;

  static String formatMonthLabel(DateTime monthStart) {
    return _monthNames[monthStart.month - 1];
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Caption for the rolling window, e.g. `Jul 2025 – Jun 2026`.
  ///
  /// [points] must be oldest-first (same order as chart axis).
  static String? formatPeriodRange(List<ChartMonthAggregate> points) {
    if (points.isEmpty) {
      return null;
    }
    final oldest = points.first.monthStart;
    final newest = points.last.monthStart;
    return '${_formatMonthYear(oldest)} – ${_formatMonthYear(newest)}';
  }

  static String _formatMonthYear(DateTime monthStart) {
    return '${_monthNames[monthStart.month - 1]} ${monthStart.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Semantics(
      label: 'Twelve month step history bar chart',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
            child: switch (status) {
              HistoryStatus.loading => _LoadingSkeleton(colors: colors),
              HistoryStatus.empty => _EmptyState(colors: colors),
              HistoryStatus.ready => _ReadyChart(
                points: points,
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
          for (var i = 0; i < 12; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AstraSpacing.kSpaceXs,
                ),
                child: Container(
                  height: 40 + (i % 4) * 16,
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
    required this.colors,
  });

  final List<ChartMonthAggregate> points;
  final AstraColors colors;

  static const _kBelowGoalBarAlpha = 0.66;
  static const _kMaxBarWidth = 12.0;
  static const _kMinBarWidth = 4.0;
  static const _kBarSlotFillRatio = 0.55;

  @override
  Widget build(BuildContext context) {
    final maxSteps = points.fold<int>(
      0,
      (max, entry) =>
          entry.averageDailySteps > max ? entry.averageDailySteps : max,
    );
    final safeYMax = (maxSteps <= 0 ? 1 : maxSteps).toDouble();
    final chartMaxY = safeYMax * 1.05;

    return ExcludeSemantics(
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

            return BarChart(
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
                              color: colors.textPrimary,
                            ),
                          );
                        }
                        if ((value - chartMaxY).abs() < chartMaxY * 0.001) {
                          return Text(
                            _formatAxisValue(safeYMax.round()),
                            style: AstraTypography.captionFor(colors).copyWith(
                              color: colors.textPrimary,
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
                        return Padding(
                          padding:
                              const EdgeInsets.only(top: AstraSpacing.kSpaceXs),
                          child: Text(
                            TrendsMonthlyBarChart.formatMonthLabel(
                              points[index].monthStart,
                            ),
                            style: AstraTypography.captionFor(colors).copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].averageDailySteps.toDouble(),
                          color: colors.accentPrimary.withValues(
                            alpha: _kBelowGoalBarAlpha,
                          ),
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static double _resolveBarWidth(double chartWidth, int pointCount) {
    if (pointCount <= 0 || chartWidth <= 0) {
      return _kMaxBarWidth;
    }
    final slotWidth = chartWidth / pointCount;
    return (slotWidth * _kBarSlotFillRatio).clamp(_kMinBarWidth, _kMaxBarWidth);
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
