import '../../data/repositories/user_preferences_repository.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/app_database.dart';

class AppDependencies {
  const AppDependencies({
    required this.userPreferences,
    required this.initialTheme,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;

  static Future<AppDependencies> create() async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
    );
  }

  static AppDependencies test({
    required UserPreferencesRepository userPreferences,
    AstraThemePreference initialTheme = AstraThemePreference.system,
  }) =>
      AppDependencies(
        userPreferences: userPreferences,
        initialTheme: initialTheme,
      );
}
