abstract class UserSettingsRepositoryContract {
  bool get isDatabaseOpen;

  Future<int?> getLastDisplayedSteps(String localDayIso);

  Future<void> setLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  });

  Future<bool> tryClaimCelebrationShownDate(String localDayIso);

  Future<DateTime?> getLastDatabaseOptimizedAt();
}
