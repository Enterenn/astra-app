import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_bar_loading_skeleton.dart';
import '../../data/models/chart_month_aggregate.dart';
import '../cubits/history_state.dart';
import '../l10n/l10n_date_labels.dart';
import 'chart/astra_bar_chart_core.dart';
import 'chart/chart_axis_ticks.dart';

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
    return monthStart.month.toString().padLeft(2, '0');
  }

  /// Caption for the rolling window, e.g. `Jul 2025 – Jun 2026`.
  ///
  /// [points] must be oldest-first (same order as chart axis).
  static String? formatPeriodRange(
    AppLocalizations l10n,
    List<ChartMonthAggregate> points,
  ) {
    if (points.isEmpty) {
      return null;
    }
    final oldest = points.first.monthStart;
    final newest = points.last.monthStart;
    return '${l10n.formatMonthYearShort(oldest)} – ${l10n.formatMonthYearShort(newest)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    final chartShell = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
          child: switch (status) {
            HistoryStatus.loading => AstraBarLoadingSkeleton(
                barCount: 12,
                barHeightAt: (i) => 40 + (i % 4) * 16,
              ),
            HistoryStatus.empty => _EmptyState(colors: colors, l10n: l10n),
            HistoryStatus.ready => _ReadyChart(
              points: points,
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
      label: l10n.trendsMonthlyBarChartSemantics,
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
          style: AstraTypography.bodyFor(colors).copyWith(
            color: colors.neutralGray,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ReadyChart extends StatefulWidget {
  const _ReadyChart({
    required this.points,
    required this.colors,
  });

  final List<ChartMonthAggregate> points;
  final AstraColors colors;

  @override
  State<_ReadyChart> createState() => _ReadyChartState();
}

class _ReadyChartState extends State<_ReadyChart> {
  static const _kBelowGoalBarAlpha = 0.66;
  static const _kSelectedBarAlpha = 0.8;
  static const _kLeftAxisReserved = 36.0;
  static const _kBottomAxisReserved = 24.0;

  int? _touchedIndex;

  @override
  void didUpdateWidget(covariant _ReadyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pointCount = widget.points.length;
    if (_touchedIndex != null &&
        (pointCount == 0 || _touchedIndex! >= pointCount)) {
      _touchedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = widget.colors;
    final points = widget.points;
    final maxSteps = points.fold<int>(
      0,
      (max, entry) =>
          entry.averageDailySteps > max ? entry.averageDailySteps : max,
    );
    final safeYMax = (maxSteps <= 0 ? 1 : maxSteps).toDouble();
    final chartMaxY = safeYMax * 1.05;
    final yTicks = computeChartYAxisTicks(maxY: chartMaxY);

    final semanticsLabel = _touchedIndex == null
        ? l10n.trendsMonthlyBarChartSemantics
        : _monthlySelectionSemanticsLabel(
            l10n: l10n,
            point: points[_touchedIndex!],
          );

    return Semantics(
      label: semanticsLabel,
      liveRegion: _touchedIndex != null,
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
              final plotWidth = constraints.maxWidth - _kLeftAxisReserved;
              final barWidth = resolveAstraBarWidth(
                chartWidth: plotWidth,
                pointCount: points.length,
              );
              final values = [
                for (final point in points)
                  point.averageDailySteps.toDouble(),
              ];

              return AstraBarChartCore(
                values: values,
                maxY: chartMaxY,
                barWidth: barWidth,
                yTicks: yTicks,
                colors: colors,
                leftAxisReserved: _kLeftAxisReserved,
                bottomAxisReserved: _kBottomAxisReserved,
                selectedIndex: _touchedIndex,
                onSelectedIndexChanged: (index) {
                  setState(() => _touchedIndex = index);
                },
                barColor: (index, isSelected) => isSelected
                    ? colors.accentPrimary.withValues(
                        alpha: _kSelectedBarAlpha,
                      )
                    : colors.accentPrimary.withValues(
                        alpha: _kBelowGoalBarAlpha,
                      ),
                bottomLabelBuilder: (index) =>
                    TrendsMonthlyBarChart.formatMonthLabel(
                      points[index].monthStart,
                    ),
                tooltipTextBuilder: (index) => _monthlyTooltipText(
                  l10n: l10n,
                  point: points[index],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _monthlySelectionSemanticsLabel({
    required AppLocalizations l10n,
    required ChartMonthAggregate point,
  }) {
    return l10n.chartMonthlySelectionSemantics(
      l10n.formatMonthYearFull(point.monthStart),
      point.averageDailySteps,
      point.totalSteps,
      point.dayCount,
    );
  }

  String _monthlyTooltipText({
    required AppLocalizations l10n,
    required ChartMonthAggregate point,
  }) {
    return '${l10n.formatMonthYearFull(point.monthStart)}\n'
        '${l10n.trendsMonthlyTooltipStepsPerDay(point.averageDailySteps)}\n'
        '${l10n.trendsMonthlyTooltipTotal(point.totalSteps, point.dayCount)}';
  }
}
