import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector_factory.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/core/time/local_day_formatter.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _FakeStepSource implements DataIngestionSource {
  const _FakeStepSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(_readings);
}

NotificationService _testNotificationService() {
  return NotificationService(
    goalNotificationPresenter: ({required id, required title, body}) async {},
    permissionChecker: () async => PermissionStatus.granted,
  );
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('createIsolateBackgroundCollector', () {
    late Database db;
    late StepAggregationRepository aggregationRepository;
    final clock = FakeTimeProvider(
      fixedNowUtc: DateTime.utc(2026, 6, 2, 10),
      zoneOffset: const Duration(hours: 2),
    );

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      aggregationRepository = StepAggregationRepository(db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'createIsolateBackgroundCollector wires repos and collects via injected source',
      () async {
        final collector = await createIsolateBackgroundCollector(
          db: db,
          sources: [
            _FakeStepSource([
              StepReading(
                cumulativeSteps: 10,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10),
              ),
              StepReading(
                cumulativeSteps: 25,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10, 1),
              ),
            ]),
          ],
          clock: clock,
          notificationService: _testNotificationService(),
          notificationPermissionGranted: () async => true,
        );

        final upserted = await collector.collectOnce();

        expect(upserted, 1);
        expect(
          await aggregationRepository.getLastIngestionUtc(),
          DateTime.utc(2026, 6, 2, 10, 5),
        );
      },
    );

    test(
      'createIsolateBackgroundCollector omits phone source when includePhonePedometerSource is false',
      () async {
        final collector = await createIsolateBackgroundCollector(
          db: db,
          sources: null,
          includePhonePedometerSource: false,
          clock: clock,
          notificationService: _testNotificationService(),
          notificationPermissionGranted: () async => true,
        );

        await collector.collectOnce();

        expect(await aggregationRepository.getLastIngestionUtc(), isNull);
      },
    );

    test(
      'createIsolateBackgroundCollector enables goal notification when background init succeeds',
      () async {
        var showCount = 0;
        final notificationService = NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
          goalNotificationPresenter: ({required id, required title, body}) async {
            showCount += 1;
          },
        );

        final userSettings = UserSettingsRepository(db);
        final userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
        await userHealthMetrics.setDailyStepGoal(5000);
        await userSettings.setGoalNotificationsEnabled(true);
        final ingestionRepository = StepIngestionRepository(db);
        await ingestionRepository.upsertIngestionBucket(
          NormalizedStepBucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 6),
            endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
            value: 4900,
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: '+02:00',
          ),
        );

        final collector = await createIsolateBackgroundCollector(
          db: db,
          sources: [
            _FakeStepSource([
              StepReading(
                cumulativeSteps: 10,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10),
              ),
              StepReading(
                cumulativeSteps: 200,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10, 1),
              ),
            ]),
          ],
          clock: clock,
          notificationService: notificationService,
          notificationPermissionGranted: () async => true,
        );

        await collector.collectOnce(enableGoalNotification: true);

        expect(showCount, 1);
        expect(await userSettings.getGoalNotificationsEnabled(), isTrue);
        expect(await userHealthMetrics.getDailyStepGoal(), 5000);
        expect(
          await userSettings.getGoalNotificationShownDate(),
          formatLocalDayIso(clock.snapshot()),
        );
        expect(
          await aggregationRepository.getLastIngestionUtc(),
          DateTime.utc(2026, 6, 2, 10, 5),
        );
      },
    );

    test(
      'createIsolateBackgroundCollector skips notification when background init times out but still collects',
      () async {
        // No goalNotificationPresenter: init must time out via platform path.
        final notificationService = NotificationService(
          platformInitializer: (_) =>
              Future<void>.delayed(const Duration(seconds: 5)),
          backgroundInitTimeout: const Duration(milliseconds: 10),
          permissionChecker: () async => PermissionStatus.granted,
        );

        final userSettings = UserSettingsRepository(db);
        final userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
        await userHealthMetrics.setDailyStepGoal(5000);
        await userSettings.setGoalNotificationsEnabled(true);
        final ingestionRepository = StepIngestionRepository(db);
        await ingestionRepository.upsertIngestionBucket(
          NormalizedStepBucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 6),
            endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
            value: 4900,
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: '+02:00',
          ),
        );

        final collector = await createIsolateBackgroundCollector(
          db: db,
          sources: [
            _FakeStepSource([
              StepReading(
                cumulativeSteps: 10,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10),
              ),
              StepReading(
                cumulativeSteps: 200,
                observedAtUtc: DateTime.utc(2026, 6, 2, 10, 1),
              ),
            ]),
          ],
          clock: clock,
          notificationService: notificationService,
          notificationPermissionGranted: () async => true,
        );

        final upserted = await collector.collectOnce(enableGoalNotification: true);

        expect(upserted, 1);
        expect(await userSettings.getGoalNotificationShownDate(), isNull);
        expect(await userSettings.getGoalNotificationsEnabled(), isTrue);
        expect(
          await aggregationRepository.getLastIngestionUtc(),
          DateTime.utc(2026, 6, 2, 10, 5),
        );
      },
    );
  });
}
