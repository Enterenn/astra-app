import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector_factory.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
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
        final userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
        await userHealthMetrics.setDailyStepGoal(7500);

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
        final verifyHealthMetrics = UserHealthMetricsRepository(db, clock: clock);

        expect(upserted, greaterThan(0));
        expect(
          await aggregationRepository.getLastIngestionUtc(),
          DateTime.utc(2026, 6, 2, 10, 5),
        );
        expect(await verifyHealthMetrics.getDailyStepGoal(), 7500);
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
  });
}
