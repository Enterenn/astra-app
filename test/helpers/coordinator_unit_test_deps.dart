import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/app_lifecycle_coordinator.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/data_lifecycle_service.dart';
import 'package:astra_app/core/services/health_foreground_service.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/datasources/adp_ble_source.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/data/services/csv_service.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

/// In-memory [Database] stub — satisfies session/repository reads without sqflite.
class CoordinatorStubDatabase extends Fake implements Database {
  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async =>
      [];

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async =>
      action(_CoordinatorStubTransaction());

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async =>
      0;
}

class _CoordinatorStubTransaction extends Fake implements Transaction {
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      1;
}

/// Builds [AppDependencies] for coordinator unit tests without opening SQLite (AC #8).
AppDependencies buildCoordinatorUnitTestDeps({
  required TimeProvider timeProvider,
  BackgroundCollector? backgroundCollector,
  LiveStepMonitor? liveStepMonitor,
  HealthForegroundServiceCoordinator? healthForegroundCoordinator,
  bool initialOnboardingComplete = true,
}) {
  const databasePath = ':memory:';
  final databaseSession = AstraDatabaseSession(
    databasePath: databasePath,
    initial: CoordinatorStubDatabase(),
  );
  final userSettings = UserSettingsRepository(databaseSession);
  final userHealthMetrics = UserHealthMetricsRepository(
    databaseSession,
    clock: timeProvider,
  );
  final stepIngestion = StepIngestionRepository(databaseSession);
  final stepAggregation = StepAggregationRepository(
    databaseSession,
    clock: timeProvider,
  );
  final csvService = CsvService(databaseSession, clock: timeProvider);
  final stepNormalizer = StepNormalizer(clock: timeProvider);
  final baselineRepository = IngestionBaselineRepository(databaseSession);
  final monitor =
      liveStepMonitor ??
      LiveStepMonitor(
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        clock: timeProvider,
        stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
      );
  final sources = <DataIngestionSource>[
    MonitorDrainSource(
      monitor,
      phoneFallback: PhonePedometerSource(
        stepEventStreamFactory: () => const Stream.empty(),
      ),
    ),
    const AdpBleSource(),
  ];
  final notifications = NotificationService(
    goalNotificationPresenter: _noopGoalNotification,
    permissionChecker: _grantedPermission,
  );
  final healthForeground =
      healthForegroundCoordinator ??
      HealthForegroundServiceCoordinator(
        activityPermissionGranted: () async => true,
      );
  final collector =
      backgroundCollector ??
      BackgroundCollector(
        sources: sources,
        normalizer: stepNormalizer,
        repository: stepIngestion,
        stepAggregation: stepAggregation,
        baselineRepository: baselineRepository,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: timeProvider,
        notificationService: notifications,
        notificationPermissionGranted: notifications.hasNotificationPermission,
      );
  final lifecycleService = DataLifecycleService(
    session: databaseSession,
    databasePath: databasePath,
    repository: stepAggregation,
    userSettings: userSettings,
    clock: timeProvider,
  );

  late AppDependencies builtDeps;
  final coordinator = AppLifecycleCoordinator(depsGetter: () => builtDeps);
  builtDeps = AppDependencies(
    userSettings: userSettings,
    userHealthMetrics: userHealthMetrics,
    initialTheme: AstraThemePreference.system,
    initialAccentPreset: kDefaultAccentPreset,
    initialDistanceUnit: DistanceDisplayUnit.metric,
    initialWeightUnit: WeightDisplayUnit.kg,
    initialHeightUnit: HeightDisplayUnit.cm,
    initialOnboardingComplete: initialOnboardingComplete,
    timeProvider: timeProvider,
    ingestionSources: sources,
    stepNormalizer: stepNormalizer,
    stepIngestion: stepIngestion,
    stepAggregation: stepAggregation,
    csvService: csvService,
    backgroundCollector: collector,
    notificationService: notifications,
    liveStepMonitor: monitor,
    activityPermissionGranted: () async => true,
    healthForegroundCoordinator: healthForeground,
    dataLifecycleService: lifecycleService,
    databaseSession: databaseSession,
    databasePath: databasePath,
    appLifecycleCoordinator: coordinator,
  );
  return builtDeps;
}

Future<void> _noopGoalNotification({
  required int id,
  required String title,
  String? body,
}) async {}

Future<PermissionStatus> _grantedPermission() async =>
    PermissionStatus.granted;
