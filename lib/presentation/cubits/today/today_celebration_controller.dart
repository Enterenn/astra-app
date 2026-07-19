import '../../../core/time/local_day_formatter.dart';
import '../../../core/time/time_provider.dart';
import '../../../data/contracts/contracts.dart';
import '../today_state.dart';

class TodayCelebrationController {
  TodayCelebrationController({
    required this.emit,
    required this.getState,
    required this.isClosed,
    required this.userSettings,
    required this.clock,
  });

  final void Function(TodayState) emit;
  final TodayState Function() getState;
  final bool Function() isClosed;
  final UserSettingsRepositoryContract userSettings;
  final TimeProvider clock;

  late bool Function() isViewingToday;

  void dismissCelebration() {
    final state = getState();
    if (state.showCelebration) {
      emit(state.copyWith(showCelebration: false));
    }
  }

  Future<void> maybeTriggerCelebration({
    required int steps,
    required int goal,
    required TodayState baseState,
  }) async {
    if (isClosed()) return;
    if (!isViewingToday()) return;
    final state = getState();
    if (goal <= 0 || steps < goal) {
      emit(baseState.copyWith(showCelebration: false));
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    if (isClosed()) return;
    if (!await userSettings.tryClaimCelebrationShownDate(todayIso)) {
      if (!isViewingToday()) return;
      emit(baseState.copyWith(showCelebration: state.showCelebration));
      return;
    }
    if (isClosed()) return;
    if (!isViewingToday()) return;
    emit(baseState.copyWith(showCelebration: true));
  }
}
