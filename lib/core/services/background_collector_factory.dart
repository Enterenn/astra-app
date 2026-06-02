import 'package:sqflite/sqflite.dart';

import '../../data/datasources/adp_ble_source.dart';
import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../time/system_time_provider.dart';
import '../time/time_provider.dart';
import 'background_collector.dart';
import 'notification_service.dart';

/// Shared isolate-safe [BackgroundCollector] bootstrap for WorkManager and FGS.
Future<BackgroundCollector> createIsolateBackgroundCollector({
  required Database db,
  List<DataIngestionSource>? sources,
  TimeProvider? clock,
  NotificationService? notificationService,
  Future<bool> Function()? notificationPermissionGranted,
  bool includePhonePedometerSource = true,
}) async {
  final timeProvider = clock ?? const SystemTimeProvider();
  final resolvedSources = sources ??
      [
        if (includePhonePedometerSource) PhonePedometerSource(),
        const AdpBleSource(),
      ];
  final notifications = notificationService ?? NotificationService();
  await notifications.initializeForBackground();
  return BackgroundCollector(
    sources: resolvedSources,
    normalizer: StepNormalizer(clock: timeProvider),
    repository: StepRepository(db: db, clock: timeProvider),
    baselineRepository: IngestionBaselineRepository(db),
    userPreferences: UserPreferencesRepository(db),
    clock: timeProvider,
    notificationService: notifications,
    notificationPermissionGranted:
        notificationPermissionGranted ??
        notifications.hasNotificationPermission,
  );
}
