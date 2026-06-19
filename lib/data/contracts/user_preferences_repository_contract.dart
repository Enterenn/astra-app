abstract class UserPreferencesRepositoryContract {
  bool get isDatabaseOpen;

  Future<int> getGoalForLocalDay(String localDayIso);

  Future<Map<String, int>> getGoalsForLocalDays(List<String> localDayIsos);

  Future<void> setDailyStepGoal(int goal);

  Future<int?> getHeightCm();

  Future<double?> getWeightKg();

  Future<int?> getLastDisplayedSteps(String localDayIso);

  Future<void> setLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  });

  Future<bool> tryClaimCelebrationShownDate(String localDayIso);

  Future<void> setDisplayName(String? name);

  Future<DateTime?> getLastDatabaseOptimizedAt();
}
