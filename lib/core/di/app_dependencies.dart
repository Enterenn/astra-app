import 'dart:io';

import 'package:path/path.dart' as p;
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
import '../services/android_platform_capability_probe.dart';
import '../services/background_collector.dart';
import '../services/data_lifecycle_service.dart';
import '../services/background_health_capability_evaluator.dart';
import '../services/health_foreground_service.dart';
import '../services/platform_capability_probe.dart';
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
    required this.backgroundHealthCapabilityEvaluator,
    required this.healthForegroundCoordinator,
    required this.dataLifecycleService,
    required this.databasePath,
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
  final BackgroundHealthCapabilityEvaluator backgroundHealthCapabilityEvaluator;
  final HealthForegroundServiceCoordinator healthForegroundCoordinator;
  final DataLifecycleService dataLifecycleService;
  final String databasePath;

  static Future<bool> resolveActivityRecognitionGranted() =>
      isActivityRecognitionGranted();

  static BackgroundHealthCapabilityEvaluator buildCapabilityEvaluator({
    Future<bool> Function()? activityRecognitionGranted,
    required Future<bool> Function() notificationGranted,
    PlatformCapabilityProbe? platformProbe,
    bool Function()? isAndroidPlatform,
  }) {
    return BackgroundHealthCapabilityEvaluator(
      activityRecognitionGranted:
          activityRecognitionGranted ?? resolveActivityRecognitionGranted,
      notificationGranted: notificationGranted,
      platformProbe:
          platformProbe ??
          _defaultPlatformProbe(isAndroidPlatform: isAndroidPlatform),
      isAndroidPlatform: isAndroidPlatform ?? () => Platform.isAndroid,
    );
  }

  static PlatformCapabilityProbe _defaultPlatformProbe({
    bool Function()? isAndroidPlatform,
  }) {
    final isAndroid = isAndroidPlatform ?? () => Platform.isAndroid;
    return isAndroid()
        ? AndroidPlatformCapabilityProbe(isAndroidPlatform: isAndroid)
        : const NoopPlatformCapabilityProbe();
  }

  static Future<AppDependencies> create({
    required NotificationService notificationService,
  }) async {
    final databasePath = p.join(await getDatabasesPath(), 'astra_app.db');
    final db = await openAstraDatabase(databasePath: databasePath);
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
    final capabilityEvaluator = buildCapabilityEvaluator(
      notificationGranted: notificationService.hasNotificationPermission,
    );
    final healthForeground = HealthForegroundServiceCoordinator(
      activityPermissionGranted: resolveActivityRecognitionGranted,
    );
    healthForeground.registerPlatformHandlers();
    final dataLifecycleService = DataLifecycleService(
      db: db,
      databasePath: databasePath,
      repository: stepRepository,
      userPreferences: userPreferences,
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
      notificationService: notificationService,
      liveStepMonitor: liveStepMonitor,
      activityPermissionGranted: resolveActivityRecognitionGranted,
      backgroundHealthCapabilityEvaluator: capabilityEvaluator,
      healthForegroundCoordinator: healthForeground,
      dataLifecycleService: dataLifecycleService,
      databasePath: databasePath,
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
    BackgroundHealthCapabilityEvaluator? backgroundHealthCapabilityEvaluator,
    PlatformCapabilityProbe? platformCapabilityProbe,
    HealthForegroundServiceCoordinator? healthForegroundCoordinator,
    DataLifecycleService? dataLifecycleService,
    String? databasePath,
    bool Function()? isAndroidPlatform,
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
    final notificationCheck =
        notificationPermissionGranted ??
        notifications.hasNotificationPermission;
    final activityCheck =
        activityPermissionGranted ?? () async => true;
    final capabilityEvaluator =
        backgroundHealthCapabilityEvaluator ??
        buildCapabilityEvaluator(
          activityRecognitionGranted: activityCheck,
          notificationGranted: notificationCheck,
          platformProbe: platformCapabilityProbe,
          isAndroidPlatform: isAndroidPlatform,
        );
    final permissionCheck = activityCheck;
    final healthForeground =
        healthForegroundCoordinator ??
        HealthForegroundServiceCoordinator(
          activityPermissionGranted: permissionCheck,
        );
    final backgroundCollector = BackgroundCollector(
      sources: sources,
      normalizer: stepNormalizer,
      repository: stepRepository,
      baselineRepository: baselineRepository,
      userPreferences: userPreferences,
      clock: clock,
      notificationService: notifications,
      notificationPermissionGranted: notificationCheck,
    );
    final lifecycleService =
        dataLifecycleService ??
        DataLifecycleService(
          db: db,
          databasePath: databasePath ?? inMemoryDatabasePath,
          repository: stepRepository,
          userPreferences: userPreferences,
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
      notificationService: notifications,
      liveStepMonitor: monitor,
      activityPermissionGranted: permissionCheck,
      backgroundHealthCapabilityEvaluator: capabilityEvaluator,
      healthForegroundCoordinator: healthForeground,
      dataLifecycleService: lifecycleService,
      databasePath: databasePath ?? inMemoryDatabasePath,
    );
  }
}
