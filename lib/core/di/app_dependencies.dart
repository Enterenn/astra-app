import 'package:sqflite/sqflite.dart';

import '../../data/datasources/adp_ble_source.dart';
import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/app_database.dart';
import '../services/background_collector.dart';
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
    required this.stepRepository,
    required this.backgroundCollector,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;
  final bool initialOnboardingComplete;
  final TimeProvider timeProvider;
  final List<DataIngestionSource> ingestionSources;
  final StepNormalizer stepNormalizer;
  final StepRepository stepRepository;
  final BackgroundCollector backgroundCollector;

  static Future<AppDependencies> create() async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    final initialOnboardingComplete = await userPreferences
        .getOnboardingComplete();
    final timeProvider = const SystemTimeProvider();
    final stepRepository = StepRepository(db: db, clock: timeProvider);
    final stepNormalizer = StepNormalizer(clock: timeProvider);
    final ingestionSources = <DataIngestionSource>[
      PhonePedometerSource(),
      const AdpBleSource(),
    ];
    final backgroundCollector = BackgroundCollector(
      sources: ingestionSources,
      normalizer: stepNormalizer,
      repository: stepRepository,
      clock: timeProvider,
    );
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: initialOnboardingComplete,
      timeProvider: timeProvider,
      ingestionSources: ingestionSources,
      stepNormalizer: stepNormalizer,
      stepRepository: stepRepository,
      backgroundCollector: backgroundCollector,
    );
  }

  /// Test factory — reads persisted prefs while avoiding live platform streams by default.
  static Future<AppDependencies> test({
    required Database db,
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
        ingestionSources ?? const <DataIngestionSource>[AdpBleSource()];
    final stepNormalizer = StepNormalizer(clock: clock);
    final stepRepository = StepRepository(db: db, clock: clock);
    final backgroundCollector = BackgroundCollector(
      sources: sources,
      normalizer: stepNormalizer,
      repository: stepRepository,
      clock: clock,
    );
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialOnboardingComplete: onboardingComplete,
      timeProvider: clock,
      ingestionSources: sources,
      stepNormalizer: stepNormalizer,
      stepRepository: stepRepository,
      backgroundCollector: backgroundCollector,
    );
  }
}
