import 'dart:async';

import '../../../presentation/cubits/history_cubit.dart';
import '../../../presentation/cubits/my_data_cubit.dart';
import '../../../presentation/cubits/today_cubit.dart';

/// Shared mutable session for lifecycle collaborators (Story 25-2).
final class LifecycleSessionState {
  TodayCubit? todayCubit;
  HistoryCubit? historyCubit;
  MyDataCubit? myDataCubit;

  bool livePipelineStarted = false;
  bool appInBackground = false;
  late Future<int> foregroundBackfill;

  DateTime? backgroundedAt;
  int? stepsAtBackground;

  bool enablePeriodicPersist = true;
  bool enableLiveStepPipeline = true;
  Duration maxPersistStaleness = const Duration(minutes: 5);
  Duration minPauseForPhoneCatchUp = const Duration(seconds: 10);

  bool Function()? isMounted;
  bool Function()? showMainShell;

  Stopwatch? coldStartStopwatch;
  bool coldStartReadyLogged = false;

  bool mounted() => isMounted?.call() ?? false;

  bool shellVisible() => showMainShell?.call() ?? false;
}
