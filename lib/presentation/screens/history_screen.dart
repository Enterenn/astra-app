import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_cubit.dart';
import '../cubits/history_state.dart';
import '../widgets/period_toggle.dart';
import '../widgets/step_bar_chart.dart';
import '../widgets/trend_chip.dart';
import '../widgets/trends_average_stats_row.dart';
import '../widgets/trends_monthly_bar_chart.dart';
import '../widgets/trends_peak_day_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _kMonthlyChartHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            return Semantics(
              label: l10n.trendsScreenTitle,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AstraSpacing.kScreenHorizontalPadding,
                    AstraSpacing.kSpaceSm,
                    AstraSpacing.kScreenHorizontalPadding,
                    bottomScrollPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.trendsScreenTitle,
                        style: AstraTypography.screenTitleFor(colors),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceMd),
                      PeriodToggle(
                        selected: state.period,
                        onChanged: context.read<HistoryCubit>().selectPeriod,
                      ),
                      if (state.period == HistoryPeriod.months12 &&
                          state.status == HistoryStatus.ready &&
                          state.monthlyChartPoints.isNotEmpty) ...[
                        const SizedBox(height: AstraSpacing.kSpaceMd),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: CaptionPill(
                            label: TrendsMonthlyBarChart.formatPeriodRange(
                              l10n,
                              state.monthlyChartPoints,
                            )!,
                          ),
                        ),
                      ],
                      if (state.trend != null &&
                          state.period != HistoryPeriod.months12) ...[
                        const SizedBox(height: AstraSpacing.kSpaceMd),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TrendChip(trend: state.trend!),
                        ),
                      ],
                      const SizedBox(height: AstraSpacing.kSpaceMd),
                      if (state.period == HistoryPeriod.months12) ...[
                        SizedBox(
                          height: _kMonthlyChartHeight,
                          child: TrendsMonthlyBarChart(
                            key: const ValueKey('months12'),
                            points: state.monthlyChartPoints,
                            status: state.status,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: StepBarChart.kDailyChartHeight,
                          child: StepBarChart(
                            key: ValueKey(state.period),
                            points: state.chartPoints,
                            dailyGoal: state.dailyGoal,
                            goalsByDay: state.goalsByDay,
                            status: state.status,
                          ),
                        ),
                        if (state.periodAverages != null) ...[
                          const SizedBox(height: AstraSpacing.kSpaceMd),
                          TrendsAverageStatsRow(averages: state.periodAverages!),
                          if (state.peakDay != null) ...[
                            const SizedBox(height: AstraSpacing.kSpaceSm),
                            TrendsPeakDayCard(
                              peakDay: state.peakDay!,
                              period: state.period,
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
