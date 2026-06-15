import 'package:flutter/foundation.dart';
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
import '../../core/constants/astra_accent_preset.dart';
import '../../presentation/cubits/theme_state.dart';
import '../database/astra_database_session.dart';
import '../permissions/activity_permission_resolver.dart';
import '../services/background_collector.dart';
import '../services/data_lifecycle_service.dart';
import '../services/health_foreground_service.dart';
import '../services/live_step_monitor.dart';
import '../services/notification_service.dart';
import '../time/system_time_provider.dart';
import '../time/time_provider.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

class AppDependencies {
  AppDependencies({
    required this.userPreferences,
    required this.initialTheme,
    required this.initialAccentPreset,
    required this.initialOnboardingComplete,
    required this.timeProvider,
    required this.ingestionSources,
    required this.stepNormalizer,
    required this.stepRepository,
    required this.backgroundCollector,
    required this.notificationService,
    required this.liveStepMonitor,
    required this.activityPermissionGranted,
    required this.healthForegroundCoordinator,
    required this.dataLifecycleService,
    required this.databaseSession,
    required this.databasePath,
  });

  final UserPreferencesRepository userPreferences;
  final AstraThemePreference initialTheme;
  final AstraAccentPreset initialAccentPreset;
  final bool initialOnboardingComplete;
  final TimeProvider timeProvider;
  final List<DataIngestionSource> ingestionSources;
  final StepNormalizer stepNormalizer;
  final StepRepository stepRepository;
  final BackgroundCollector backgroundCollector;
  final NotificationService notificationService;
  final LiveStepMonitor liveStepMonitor;
  final ActivityPermissionChecker activityPermissionGranted;
  final HealthForegroundServiceCoordinator healthForegroundCoordinator;
  final DataLifecycleService dataLifecycleService;
  final AstraDatabaseSession databaseSession;
  final String databasePath;

  static Future<bool> resolveActivityRecognitionGranted() =>
      isActivityRecognitionGranted();

  static Future<AppDependencies> create({
    required NotificationService notificationService,
  }) async {
    final databasePath = p.join(await getDatabasesPath(), 'astra_app.db');
    final databaseSession = AstraDatabaseSession(databasePath: databasePath);
    await databaseSession.ensureOpen();
    final timeProvider = const SystemTimeProvider();
    final userPreferences = UserPreferencesRepository(
      databaseSession,
      clock: timeProvider,
    );
    final initialTheme = await userPreferences.getThemeMode();
    final initialAccentPreset = await userPreferences.getAccentPreset();
    final initialOnboardingComplete = await userPreferences
        .getOnboardingComplete();
    final stepRepository = StepRepository(
      session: databaseSession,
      clock: timeProvider,
    );
    final stepNormalizer = StepNormalizer(clock: timeProvider);
    final baselineRepository = IngestionBaselineRepository(databaseSession);
    final liveStepMonitor = LiveStepMonitor(
      stepRepository: stepRepository,
      baselineRepository: baselineRepository,
      clock: timeProvider,
    );
    final ingestionSources = <DataIngestionSource>[
      MonitorDrainSource(liveStepMonitor),
      const AdpBleSource(),
    ];
    HealthForegroundServiceCoordinator? healthForegroundRef;
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
      isUserFacingAppActive: () => healthForegroundRef?.isUiActive ?? true,
    );
    final healthForeground = HealthForegroundServiceCoordinator(
      activityPermissionGranted: resolveActivityRecognitionGranted,
      // Reuse the UI [Database] — opening/closing a second connection on the same
      // file path (see [runFgsStepCollectionCycle]) can close the app connection
      // while the file picker is open (import → postImportRefresh).
      collectionRunner: ({bool skipPhoneSourceWhenUiActive = false}) async {
        try {
          await backgroundCollector.collectOnce(enableGoalNotification: true);
          return true;
        } catch (error, stackTrace) {
          debugPrint('Health FGS in-process collection failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          return false;
        }
      },
    );
    healthForegroundRef = healthForeground;
    healthForeground.registerPlatformHandlers();
    final dataLifecycleService = DataLifecycleService(
      session: databaseSession,
      databasePath: databasePath,
      repository: stepRepository,
      userPreferences: userPreferences,
      clock: timeProvider,
    );

    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialAccentPreset: initialAccentPreset,
      initialOnboardingComplete: initialOnboardingComplete,
      timeProvider: timeProvider,
      ingestionSources: ingestionSources,
      stepNormalizer: stepNormalizer,
      stepRepository: stepRepository,
      backgroundCollector: backgroundCollector,
      notificationService: notificationService,
      liveStepMonitor: liveStepMonitor,
      activityPermissionGranted: resolveActivityRecognitionGranted,
      healthForegroundCoordinator: healthForeground,
      dataLifecycleService: dataLifecycleService,
      databaseSession: databaseSession,
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
    HealthForegroundServiceCoordinator? healthForegroundCoordinator,
    DataLifecycleService? dataLifecycleService,
    String? databasePath,
  }) async {
    final initialTheme = await userPreferences.getThemeMode();
    final initialAccentPreset = await userPreferences.getAccentPreset();
    final onboardingComplete =
        initialOnboardingComplete ??
        await userPreferences.getOnboardingComplete();
    final clock = timeProvider ?? const SystemTimeProvider();
    final path = databasePath ?? inMemoryDatabasePath;
    final databaseSession = AstraDatabaseSession(
      databasePath: path,
      initial: db,
    );
    final stepRepository = StepRepository(session: databaseSession, clock: clock);
    final stepNormalizer = StepNormalizer(clock: clock);
    final baselineRepository = IngestionBaselineRepository(databaseSession);
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
        <DataIngestionSource>[
          MonitorDrainSource(
            monitor,
            // Prevent real pedometer channel from opening in test environments
            // when the monitor is not running and MonitorDrainSource falls back.
            phoneFallback: PhonePedometerSource(
              stepEventStreamFactory: () => const Stream.empty(),
            ),
          ),
          const AdpBleSource(),
        ];
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
          session: databaseSession,
          databasePath: path,
          repository: stepRepository,
          userPreferences: userPreferences,
          clock: clock,
        );
    return AppDependencies(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
      initialAccentPreset: initialAccentPreset,
      initialOnboardingComplete: onboardingComplete,
      timeProvider: clock,
      ingestionSources: sources,
      stepNormalizer: stepNormalizer,
      stepRepository: stepRepository,
      backgroundCollector: backgroundCollector,
      notificationService: notifications,
      liveStepMonitor: monitor,
      activityPermissionGranted: permissionCheck,
      healthForegroundCoordinator: healthForeground,
      dataLifecycleService: lifecycleService,
      databaseSession: databaseSession,
      databasePath: path,
    );
  }
}
