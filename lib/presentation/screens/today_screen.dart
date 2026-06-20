import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../helpers/collection_health_evaluator.dart';
import '../cubits/today_cubit.dart';
import '../cubits/today_state.dart';
import '../widgets/activity_stats_row.dart';
import '../widgets/collection_health_indicator.dart';
import '../widgets/elevated_card.dart';
import '../widgets/goal_celebration.dart';
import '../widgets/goal_editor_sheet.dart';
import '../widgets/astra_pressable.dart';
import '../widgets/goal_ring.dart';
import '../models/week_day_status.dart';
import '../widgets/section_card.dart';
import '../widgets/status_banner.dart';
import '../widgets/week_progress_row.dart';
import '../widgets/week_trophy_badge.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        child: Semantics(
          label: l10n.todayScreenTitle,
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
                Builder(
                  builder: (context) {
                    _probeSectionBuild('staticTitle');
                    return Text(
                      l10n.todayScreenTitle,
                      style: AstraTypography.screenTitleFor(colors),
                    );
                  },
                ),
                const _StaleBannerSlot(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _WeekSection(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _GoalRingCard(),
                const _PermissionCta(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _ActivityStatsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int countWeekGoalsMet(List<WeekDayStatus> days) =>
    days.where((day) => !day.isFuture && day.goalMet).length;

/// Optional hook for build-isolation widget tests (Story 16-5).
@visibleForTesting
void Function(String section)? todaySectionBuildProbe;

void _probeSectionBuild(String section) => todaySectionBuildProbe?.call(section);

@visibleForTesting
bool todayWeekSliceEquals(TodayState a, TodayState b) =>
    _WeekProgressViewModel.fromState(a) == _WeekProgressViewModel.fromState(b);

@visibleForTesting
bool todayGoalRingSliceEquals(TodayState a, TodayState b) =>
    _GoalRingViewModel.fromState(a) == _GoalRingViewModel.fromState(b);

@visibleForTesting
Object todayWeekSelectorSlice(TodayState state) =>
    _WeekProgressViewModel.fromState(state);

@visibleForTesting
Object todayActivityStatsSelectorSlice(TodayState state) =>
    _ActivityStatsViewModel.fromState(state);

@visibleForTesting
Object todayGoalRingSelectorSlice(TodayState state) =>
    _GoalRingViewModel.fromState(state);

@visibleForTesting
bool todayHealthSliceEquals(TodayState a, TodayState b) =>
    _CollectionHealthViewModel.fromState(a) ==
    _CollectionHealthViewModel.fromState(b);

@visibleForTesting
Object todayHealthSelectorSlice(TodayState state) =>
    _CollectionHealthViewModel.fromState(state);

@visibleForTesting
bool todayStaleBannerVisible(TodayState state) =>
    state.isStale &&
    state.status != TodayStatus.noPermission &&
    state.status != TodayStatus.loading;

bool _sameLocalDay(DateTime? a, DateTime? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return a == b;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _localDayHash(DateTime? day) {
  if (day == null) {
    return 0;
  }
  return Object.hash(day.year, day.month, day.day);
}

@immutable
final class _WeekProgressViewModel {
  const _WeekProgressViewModel({
    required this.weekDays,
    required this.selectedLocalDay,
  });

  final List<WeekDayStatus> weekDays;
  final DateTime? selectedLocalDay;

  static _WeekProgressViewModel fromState(TodayState state) =>
      _WeekProgressViewModel(
        weekDays: state.weekDays,
        selectedLocalDay: state.selectedLocalDay,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _WeekProgressViewModel &&
        listEquals(weekDays, other.weekDays) &&
        _sameLocalDay(selectedLocalDay, other.selectedLocalDay);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(weekDays), _localDayHash(selectedLocalDay));
}

@immutable
final class _ActivityStatsViewModel {
  const _ActivityStatsViewModel({required this.status, required this.metrics});

  final TodayStatus status;
  final ActivityMetricsSnapshot metrics;

  static _ActivityStatsViewModel fromState(TodayState state) =>
      _ActivityStatsViewModel(
        status: state.status,
        metrics: state.activityMetrics,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _ActivityStatsViewModel) {
      return false;
    }
    return status == other.status &&
        metrics.distanceKm == other.metrics.distanceKm &&
        metrics.kcal == other.metrics.kcal &&
        metrics.walkingDuration == other.metrics.walkingDuration;
  }

  @override
  int get hashCode =>
      Object.hash(status, metrics.distanceKm, metrics.kcal, metrics.walkingDuration);
}

@immutable
final class _CollectionHealthViewModel {
  const _CollectionHealthViewModel({
    required this.display,
    required this.lastIngestionUtc,
  });

  final CollectionHealthDisplay display;
  final DateTime? lastIngestionUtc;

  static _CollectionHealthViewModel fromState(TodayState state) =>
      _CollectionHealthViewModel(
        display: deriveCollectionHealthDisplay(
          status: state.status,
          isStale: state.isStale,
        ),
        lastIngestionUtc: state.lastIngestionUtc,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _CollectionHealthViewModel &&
        display == other.display &&
        lastIngestionUtc == other.lastIngestionUtc;
  }

  @override
  int get hashCode => Object.hash(display, lastIngestionUtc);
}

@immutable
final class _GoalRingViewModel {
  const _GoalRingViewModel({
    required this.status,
    required this.steps,
    required this.goal,
    required this.foregroundCatchUp,
    required this.catchUpTargetSteps,
    required this.lastDisplayedSteps,
    required this.lastDisplayedStepsLoaded,
    required this.selectedLocalDay,
    required this.showCelebration,
  });

  final TodayStatus status;
  final int steps;
  final int goal;
  final bool foregroundCatchUp;
  final int? catchUpTargetSteps;
  final int? lastDisplayedSteps;
  final bool lastDisplayedStepsLoaded;
  final DateTime? selectedLocalDay;
  final bool showCelebration;

  static _GoalRingViewModel fromState(TodayState state) => _GoalRingViewModel(
        status: state.status,
        steps: state.steps,
        goal: state.goal,
        foregroundCatchUp: state.foregroundCatchUp,
        catchUpTargetSteps: state.catchUpTargetSteps,
        lastDisplayedSteps: state.lastDisplayedSteps,
        lastDisplayedStepsLoaded: state.lastDisplayedStepsLoaded,
        selectedLocalDay: state.selectedLocalDay,
        showCelebration: state.showCelebration,
      );

  TodayState toTodayState() => TodayState(
        status: status,
        steps: steps,
        goal: goal,
        showCelebration: showCelebration,
        foregroundCatchUp: foregroundCatchUp,
        catchUpTargetSteps: catchUpTargetSteps,
        selectedLocalDay: selectedLocalDay,
        lastDisplayedSteps: lastDisplayedSteps,
        lastDisplayedStepsLoaded: lastDisplayedStepsLoaded,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _GoalRingViewModel) {
      return false;
    }
    return status == other.status &&
        steps == other.steps &&
        goal == other.goal &&
        foregroundCatchUp == other.foregroundCatchUp &&
        catchUpTargetSteps == other.catchUpTargetSteps &&
        lastDisplayedSteps == other.lastDisplayedSteps &&
        lastDisplayedStepsLoaded == other.lastDisplayedStepsLoaded &&
        _sameLocalDay(selectedLocalDay, other.selectedLocalDay) &&
        showCelebration == other.showCelebration;
  }

  @override
  int get hashCode => Object.hash(
        status,
        steps,
        goal,
        foregroundCatchUp,
        catchUpTargetSteps,
        lastDisplayedSteps,
        lastDisplayedStepsLoaded,
        _localDayHash(selectedLocalDay),
        showCelebration,
      );
}

class _StaleBannerSlot extends StatelessWidget {
  const _StaleBannerSlot();

  static const sectionKey = Key('today_stale_banner_slot');

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TodayCubit, TodayState, bool>(
      key: sectionKey,
      selector: todayStaleBannerVisible,
      builder: (context, showStaleBanner) {
        _probeSectionBuild('staleBanner');
        if (!showStaleBanner) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(
              variant: StatusBannerVariant.staleCompact,
              onTap: () =>
                  context.read<TodayCubit>().refresh(silent: false),
            ),
          ],
        );
      },
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection();

  static const sectionKey = Key('today_week_section');

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TodayCubit, TodayState, _WeekProgressViewModel>(
      key: sectionKey,
      selector: _WeekProgressViewModel.fromState,
      builder: (context, vm) {
        _probeSectionBuild('week');
        final l10n = AppLocalizations.of(context);
        return SectionCard(
          headline: l10n.todayWeekSectionHeadline,
          trailing: vm.weekDays.isEmpty
              ? null
              : WeekTrophyBadge(
                  goalsMetCount: countWeekGoalsMet(vm.weekDays),
                ),
          child: vm.weekDays.isEmpty
              ? const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                )
              : WeekProgressRow(
                  days: vm.weekDays,
                  selectedLocalDay: vm.selectedLocalDay ??
                      vm.weekDays
                          .firstWhere(
                            (day) => day.isToday,
                            orElse: () => vm.weekDays.first,
                          )
                          .localDay,
                  onDayTap: context.read<TodayCubit>().selectLocalDay,
                ),
        );
      },
    );
  }
}

class _PermissionCta extends StatelessWidget {
  const _PermissionCta();

  static const sectionKey = Key('today_permission_cta');

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TodayCubit, TodayState, bool>(
      key: sectionKey,
      selector: (state) => state.status == TodayStatus.noPermission,
      builder: (context, showCta) {
        if (!showCta) {
          return const SizedBox.shrink();
        }
        final colors = context.astraColors;
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AstraSpacing.kSpaceSm),
            TextButton(
              onPressed: () => openAppSettings(),
              child: Text(
                l10n.errorNoPermission,
                style: AstraTypography.captionFor(colors),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityStatsSection extends StatelessWidget {
  const _ActivityStatsSection();

  static const sectionKey = Key('today_activity_stats_section');

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TodayCubit, TodayState, _ActivityStatsViewModel>(
      key: sectionKey,
      selector: _ActivityStatsViewModel.fromState,
      builder: (context, vm) {
        _probeSectionBuild('activityStats');
        return ElevatedCard(
          child: ActivityStatsRow(
            status: vm.status,
            metrics: vm.metrics,
          ),
        );
      },
    );
  }
}

class _CollectionHealthSlot extends StatelessWidget {
  const _CollectionHealthSlot();

  static const sectionKey = Key('today_health_slot');

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TodayCubit, TodayState, _CollectionHealthViewModel>(
      key: sectionKey,
      selector: _CollectionHealthViewModel.fromState,
      builder: (context, vm) {
        _probeSectionBuild('health');
        if (vm.display == CollectionHealthDisplay.loading) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            CollectionHealthIndicator(
              display: vm.display,
              lastIngestionUtc: vm.lastIngestionUtc,
              nowUtc: DateTime.now().toUtc(),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
        );
      },
    );
  }
}

class _GoalRingCard extends StatelessWidget {
  const _GoalRingCard();

  static const sectionKey = Key('today_goal_ring_card');

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return ElevatedCard(
      key: sectionKey,
      padding: AstraSpacing.kSpaceLg,
      child: Column(
        children: [
          const _CollectionHealthSlot(),
          BlocSelector<TodayCubit, TodayState, _GoalRingViewModel>(
            selector: _GoalRingViewModel.fromState,
            builder: (context, vm) {
              _probeSectionBuild('goalRing');
              final cubit = context.read<TodayCubit>();
              final ringState = vm.toTodayState();
              return Center(
                child: vm.showCelebration
                    ? GoalCelebration(
                        state: ringState,
                        onComplete: cubit.dismissCelebration,
                      )
                    : GoalRing(
                        state: ringState,
                        onForegroundCatchUpHandled: cubit.clearForegroundCatchUp,
                        onLastDisplayedStepsChanged:
                            cubit.recordLastDisplayedSteps,
                      ),
              );
            },
          ),
          const SizedBox(height: AstraSpacing.kSpaceLg),
          Builder(
            builder: (context) {
              _probeSectionBuild('staticSetGoal');
              final l10n = AppLocalizations.of(context);
              return Center(
                child: AstraPressable(
                  child: Material(
                    color: colors.bgSubtle,
                    borderRadius:
                        BorderRadius.circular(AstraSpacing.kRadiusFull),
                    child: InkWell(
                      onTap: () => _onSetGoalTapped(context),
                      borderRadius:
                          BorderRadius.circular(AstraSpacing.kRadiusFull),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AstraSpacing.kSpaceLg,
                          vertical: AstraSpacing.kSpaceSm,
                        ),
                        child: Text(
                          l10n.todaySetGoalLabel,
                          style: AstraTypography.labelFor(colors),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onSetGoalTapped(BuildContext context) async {
    final cubit = context.read<TodayCubit>();
    final currentGoal = await cubit.todayEditableGoal;
    if (!context.mounted) {
      return;
    }
    final result = await showGoalEditorSheet(
      context,
      currentGoal: currentGoal,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final saved = await cubit.updateDailyStepGoal(result);
    if (!context.mounted) {
      return;
    }
    if (!saved) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.todayGoalSaveError),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Test hooks for build-isolation widget tests (Story 16-5).
@visibleForTesting
Widget buildTodayWeekSectionForTest() => const _WeekSection();

@visibleForTesting
Widget buildTodayHealthSlotForTest() => const _CollectionHealthSlot();

@visibleForTesting
Widget buildTodayStaleBannerSlotForTest() => const _StaleBannerSlot();

@visibleForTesting
Widget buildTodayActivityStatsSectionForTest() => const _ActivityStatsSection();

@visibleForTesting
Widget buildActivityStatsRowForSelectorSlice(Object slice) {
  final vm = slice as _ActivityStatsViewModel;
  return ActivityStatsRow(status: vm.status, metrics: vm.metrics);
}
