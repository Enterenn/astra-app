import 'package:flutter/foundation.dart';
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
import '../widgets/goal_ring.dart';
import '../widgets/section_card.dart';
import '../widgets/week_progress_row.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _kScreenTitle = "Today's activity";
  static const _kSetGoalLabel = 'Set goal';
  static const kPreviewGoalCelebrationLabel = 'Preview goal';

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
                    const ElevatedCard(child: ActivityStatsRow()),
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
    final cubit = context.read<TodayCubit>();

    return ElevatedCard(
      child: Column(
        children: [
          Center(
            child: state.showCelebration
                ? GoalCelebration(
                    key: ValueKey(state.celebrationPreviewNonce),
                    state: _celebrationDisplayState(state),
                    onComplete: () => cubit.dismissCelebration(),
                  )
                : GoalRing(
                    key: state.isGoalPreviewActive
                        ? ValueKey('preview-${state.goalPreviewNonce}')
                        : null,
                    state: state,
                    userPreferences: cubit.userPreferences,
                    localDayIso: formatLocalDayIso(cubit.clock.snapshot()),
                    previewCountUpTarget: state.isGoalPreviewActive
                        ? state.goal
                        : null,
                    onPreviewCountUpComplete: state.isGoalPreviewActive
                        ? cubit.completeGoalPreviewCountUp
                        : null,
                  ),
          ),
          const SizedBox(height: AstraSpacing.kSpaceLg),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AstraSpacing.kSpaceSm,
              runSpacing: AstraSpacing.kSpaceSm,
              children: [
                _GoalActionChip(
                  label: TodayScreen._kSetGoalLabel,
                  onTap: () => _onSetGoalTapped(context),
                ),
                if (kDebugMode)
                  _GoalActionChip(
                    label: TodayScreen.kPreviewGoalCelebrationLabel,
                    onTap: cubit.previewCelebration,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TodayState _celebrationDisplayState(TodayState state) {
    if (state.steps >= state.goal && state.goal > 0) {
      return state;
    }
    return TodayState.fromData(
      steps: state.goal,
      goal: state.goal,
      displayName: state.displayName,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      showCelebration: state.showCelebration,
      celebrationPreviewNonce: state.celebrationPreviewNonce,
      weekDays: state.weekDays,
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

class _GoalActionChip extends StatelessWidget {
  const _GoalActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Material(
      color: colors.bgSubtle,
      borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AstraSpacing.kSpaceLg,
            vertical: AstraSpacing.kSpaceSm,
          ),
          child: Text(label, style: AstraTypography.labelFor(colors)),
        ),
      ),
    );
  }
}
