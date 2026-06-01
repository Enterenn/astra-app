import '../../data/repositories/user_preferences_repository.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/app_database.dart';

class AppDependencies {
  const AppDependencies({
    required this.userPreferences,
    required this.initialTheme,
    required this.initialOnboardingComplete,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;
  final bool initialOnboardingComplete;

  static Future<AppDependencies> create() async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    final initialOnboardingComplete =
        await userPreferences.getOnboardingComplete();
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: initialOnboardingComplete,
    );
  }

  /// Test factory — reads persisted prefs, mirroring [create].
  static Future<AppDependencies> test({
    required UserPreferencesRepository userPreferences,
    bool? initialOnboardingComplete,
  }) async {
    final initialTheme = await userPreferences.getThemeMode();
    final onboardingComplete = initialOnboardingComplete ??
        await userPreferences.getOnboardingComplete();
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: onboardingComplete,
    );
  }
}
