abstract class UserHealthMetricsRepositoryContract {
  Future<int> getGoalForLocalDay(String localDayIso);

  Future<Map<String, int>> getGoalsForLocalDays(List<String> localDayIsos);

  Future<void> setDailyStepGoal(int goal);

  Future<int?> getHeightCm();

  Future<double?> getWeightKg();

  Future<void> setDisplayName(String? name);
}
