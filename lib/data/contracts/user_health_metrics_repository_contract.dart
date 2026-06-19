abstract class UserHealthMetricsRepositoryContract {
  Future<int> getGoalForLocalDay(String localDayIso);

  Future<Map<String, int>> getGoalsForLocalDays(List<String> localDayIsos);

  Future<void> setDailyStepGoal(int goal);

  Future<String?> getDisplayName();

  Future<int?> getHeightCm();

  Future<double?> getWeightKg();

  Future<void> setHeightCm(int? heightCm);

  Future<void> setWeightKg(double? weightKg);

  Future<void> setDisplayName(String? name);
}
