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

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _kScreenTitle = 'Trends';

  @override
  Widget build(BuildContext context) {
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
              label: _kScreenTitle,
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
                      _kScreenTitle,
                      style: AstraTypography.screenTitleFor(colors),
                    ),
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                    PeriodToggle(
                      selected: state.period,
                      onChanged: context.read<HistoryCubit>().selectPeriod,
                    ),
                    if (state.trend != null) ...[
                      const SizedBox(height: AstraSpacing.kSpaceMd),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TrendChip(trend: state.trend!),
                      ),
                    ],
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                    Expanded(
                      child: StepBarChart(
                        key: ValueKey(state.period),
                        points: state.chartPoints,
                        dailyGoal: state.dailyGoal,
                        goalsByDay: state.goalsByDay,
                        status: state.status,
                      ),
                    ),
                    if (state.status == HistoryStatus.ready &&
                        state.periodAverages != null) ...[
                      const SizedBox(height: AstraSpacing.kSpaceMd),
                      TrendsAverageStatsRow(averages: state.periodAverages!),
                    ],
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
