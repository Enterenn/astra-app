import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../presentation/cubits/theme_state.dart';

abstract class UserSettingsRepositoryContract {
  bool get isDatabaseOpen;

  Future<void> setThemeMode(AstraThemePreference preference);

  Future<void> setAccentPreset(AstraAccentPreset preset);

  Future<void> setDistanceDisplayUnit(DistanceDisplayUnit unit);

  Future<void> setWeightDisplayUnit(WeightDisplayUnit unit);

  Future<void> setHeightDisplayUnit(HeightDisplayUnit unit);

  Future<bool> getGoalNotificationsEnabled();

  Future<void> setGoalNotificationsEnabled(bool enabled);

  Future<void> setOnboardingComplete(bool complete);

  Future<String?> getAppLocale();

  Future<void> setAppLocale(String languageCode);

  Future<void> clearAppLocale();

  Future<int?> getLastDisplayedSteps(String localDayIso);

  Future<void> setLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  });

  Future<bool> tryClaimCelebrationShownDate(String localDayIso);

  Future<DateTime?> getLastDatabaseOptimizedAt();
}
