import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_cubit.dart';
import '../cubits/today_state.dart';
import '../widgets/activity_stats_row.dart';
import '../widgets/elevated_card.dart';
import '../widgets/goal_celebration.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/astra_pressable.dart';
import '../widgets/goal_ring.dart';
import '../widgets/section_card.dart';
import '../widgets/status_banner.dart';
import '../widgets/week_progress_row.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _kScreenTitle = "Today's activity";
  static const _kSetGoalLabel = 'Set goal';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;

    return ColoredBox(
      color: colors.bgBase,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<TodayCubit, TodayState>(
          builder: (context, state) {
            return Semantics(
              label: _kScreenTitle,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AstraSpacing.kSpaceSm,
                  horizontalPadding,
                  bottomScrollPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _kScreenTitle,
                      style: AstraTypography.screenTitleFor(colors),
                    ),
                    if (state.isStale) ...[
                      const SizedBox(height: AstraSpacing.kSpaceMd),
                      const StatusBanner(
                        variant: StatusBannerVariant.staleCompact,
                      ),
                    ],
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                    _GoalRingCard(state: state),
                    if (state.status == TodayStatus.noPermission) ...[
                      const SizedBox(height: AstraSpacing.kSpaceSm),
                      TextButton(
                        onPressed: () => openAppSettings(),
                        child: Text(
                          'Open settings to allow step access',
                          style: AstraTypography.captionFor(colors),
                        ),
                      ),
                    ],
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                    ElevatedCard(
                      child: ActivityStatsRow(
                        status: state.status,
                        metrics: state.activityMetrics,
                      ),
                    ),
                    const SizedBox(height: AstraSpacing.kSpaceMd),
                    SectionCard(
                      headline: 'This week',
                      child: state.weekDays.isEmpty
                          ? const SizedBox(
                              height: 72,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : WeekProgressRow(days: state.weekDays),
                    ),
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

class _GoalRingCard extends StatelessWidget {
  const _GoalRingCard({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final cubit = context.read<TodayCubit>();

    return ElevatedCard(
      padding: AstraSpacing.kSpaceLg,
      child: Column(
        children: [
          Center(
            child: state.showCelebration
                ? GoalCelebration(
                    state: state,
                    onComplete: () => cubit.dismissCelebration(),
                  )
                : GoalRing(
                    state: state,
                    userPreferences: cubit.userPreferences,
                    localDayIso: formatLocalDayIso(cubit.clock.snapshot()),
                    onForegroundCatchUpHandled: cubit.clearForegroundCatchUp,
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceLg),
          Center(
            child: AstraPressable(
              child: Material(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
                child: InkWell(
                  onTap: () => _onSetGoalTapped(context),
                  borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AstraSpacing.kSpaceLg,
                      vertical: AstraSpacing.kSpaceSm,
                    ),
                    child: Text(
                      TodayScreen._kSetGoalLabel,
                      style: AstraTypography.labelFor(colors),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSetGoalTapped(BuildContext context) async {
    final cubit = context.read<TodayCubit>();
    final result = await showGoalEditorSheet(
      context,
      currentGoal: state.goal,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final saved = await cubit.updateDailyStepGoal(result);
    if (!context.mounted) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily goal could not be saved. Try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
