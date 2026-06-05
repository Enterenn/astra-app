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

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AstraSpacing.kScreenHorizontalPadding,
                AstraSpacing.kSpaceSm,
                AstraSpacing.kScreenHorizontalPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'History',
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
                      status: state.status,
                    ),
                  ),
                  const SizedBox(height: AstraSpacing.kSpaceMd),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
