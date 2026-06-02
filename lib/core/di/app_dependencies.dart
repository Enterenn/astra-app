import '../../data/datasources/adp_ble_source.dart';
import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/app_database.dart';
import '../time/system_time_provider.dart';
import '../time/time_provider.dart';

class AppDependencies {
  const AppDependencies({
    required this.userPreferences,
    required this.initialTheme,
    required this.initialOnboardingComplete,
    required this.timeProvider,
    required this.ingestionSources,
    required this.stepNormalizer,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;
  final bool initialOnboardingComplete;
  final TimeProvider timeProvider;
  final List<DataIngestionSource> ingestionSources;
  final StepNormalizer stepNormalizer;

  static Future<AppDependencies> create() async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    final initialOnboardingComplete = await userPreferences
        .getOnboardingComplete();
    final timeProvider = const SystemTimeProvider();
    final ingestionSources = <DataIngestionSource>[
      PhonePedometerSource(),
      const AdpBleSource(),
    ];
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: initialOnboardingComplete,
      timeProvider: timeProvider,
      ingestionSources: ingestionSources,
      stepNormalizer: StepNormalizer(clock: timeProvider),
    );
  }

  /// Test factory — reads persisted prefs, mirroring [create].
  static Future<AppDependencies> test({
    required UserPreferencesRepository userPreferences,
    bool? initialOnboardingComplete,
    TimeProvider? timeProvider,
    List<DataIngestionSource>? ingestionSources,
  }) async {
    final initialTheme = await userPreferences.getThemeMode();
    final onboardingComplete =
        initialOnboardingComplete ??
        await userPreferences.getOnboardingComplete();
    final clock = timeProvider ?? const SystemTimeProvider();
    final sources =
        ingestionSources ??
        <DataIngestionSource>[PhonePedometerSource(), const AdpBleSource()];
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: onboardingComplete,
      timeProvider: clock,
      ingestionSources: sources,
      stepNormalizer: StepNormalizer(clock: clock),
    );
  }
}
