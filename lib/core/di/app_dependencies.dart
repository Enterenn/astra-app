import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/datasources/adp_ble_source.dart';
import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/monitor_drain_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/app_database.dart';
import '../permissions/activity_permission_resolver.dart';
import '../services/background_collector.dart';
import '../services/live_step_monitor.dart';
import '../services/notification_service.dart';
import '../time/system_time_provider.dart';
import '../time/time_provider.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

class AppDependencies {
  AppDependencies({
    required this.userPreferences,
    required this.initialTheme,
    required this.initialOnboardingComplete,
    required this.timeProvider,
    required this.ingestionSources,
    required this.stepNormalizer,
    required this.stepRepository,
    required this.backgroundCollector,
    required this.notificationService,
    required this.liveStepMonitor,
    required this.activityPermissionGranted,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;
  final bool initialOnboardingComplete;
  final TimeProvider timeProvider;
  final List<DataIngestionSource> ingestionSources;
  final StepNormalizer stepNormalizer;
  final StepRepository stepRepository;
  final BackgroundCollector backgroundCollector;
  final NotificationService notificationService;
  final LiveStepMonitor liveStepMonitor;
  final ActivityPermissionChecker activityPermissionGranted;

  static Future<bool> defaultActivityPermissionGranted() async {
    final permission = resolveActivityPermission();
    final status = await permission.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  static Future<AppDependencies> create({
    required NotificationService notificationService,
  }) async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    final initialOnboardingComplete = await userPreferences
        .getOnboardingComplete();
    final timeProvider = const SystemTimeProvider();
    final stepRepository = StepRepository(db: db, clock: timeProvider);
    final stepNormalizer = StepNormalizer(clock: timeProvider);
    final baselineRepository = IngestionBaselineRepository(db);
    final liveStepMonitor = LiveStepMonitor(
      stepRepository: stepRepository,
      baselineRepository: baselineRepository,
      clock: timeProvider,
    );
    final ingestionSources = <DataIngestionSource>[
      MonitorDrainSource(liveStepMonitor),
      const AdpBleSource(),
    ];
    final backgroundCollector = BackgroundCollector(
      sources: ingestionSources,
      normalizer: stepNormalizer,
      repository: stepRepository,
      baselineRepository: baselineRepository,
      userPreferences: userPreferences,
      clock: timeProvider,
      notificationService: notificationService,
      notificationPermissionGranted:
          notificationService.hasNotificationPermission,
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
      notificationService: notificationService,
      liveStepMonitor: liveStepMonitor,
      activityPermissionGranted: defaultActivityPermissionGranted,
    );
  }

  /// Test factory — reads persisted prefs while avoiding live platform streams by default.
  static Future<AppDependencies> test({
    required Database db,
    required UserPreferencesRepository userPreferences,
    bool? initialOnboardingComplete,
    TimeProvider? timeProvider,
    List<DataIngestionSource>? ingestionSources,
    NotificationService? notificationService,
    Future<bool> Function()? notificationPermissionGranted,
    LiveStepMonitor? liveStepMonitor,
    ActivityPermissionChecker? activityPermissionGranted,
  }) async {
    final initialTheme = await userPreferences.getThemeMode();
    final onboardingComplete =
        initialOnboardingComplete ??
        await userPreferences.getOnboardingComplete();
    final clock = timeProvider ?? const SystemTimeProvider();
    final stepRepository = StepRepository(db: db, clock: clock);
    final stepNormalizer = StepNormalizer(clock: clock);
    final baselineRepository = IngestionBaselineRepository(db);
    final monitor =
        liveStepMonitor ??
        LiveStepMonitor(
          stepRepository: stepRepository,
          baselineRepository: baselineRepository,
          clock: clock,
          stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
        );
    final sources =
        ingestionSources ??
        <DataIngestionSource>[MonitorDrainSource(monitor), const AdpBleSource()];
    final notifications =
        notificationService ??
        NotificationService(
          goalNotificationPresenter:
              ({required id, required title, body}) async {},
          permissionChecker: () async => PermissionStatus.granted,
        );
    final permissionCheck =
        activityPermissionGranted ??
        notificationPermissionGranted ??
        () async => true;
    final backgroundCollector = BackgroundCollector(
      sources: sources,
      normalizer: stepNormalizer,
      repository: stepRepository,
      baselineRepository: baselineRepository,
      userPreferences: userPreferences,
      clock: clock,
      notificationService: notifications,
      notificationPermissionGranted: permissionCheck,
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
      notificationService: notifications,
      liveStepMonitor: monitor,
      activityPermissionGranted: permissionCheck,
    );
  }
}
