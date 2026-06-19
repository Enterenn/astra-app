import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/data_lifecycle_service.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/datasources/adp_ble_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';
import '../time/fake_time_provider.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AppDependencies ingestion wiring', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'test factory exposes time provider, sources, and normalizer',
      () async {
        final clock = FakeTimeProvider(
          fixedNowUtc: DateTime.utc(2026, 6, 2, 7),
          zoneOffset: const Duration(hours: 2),
        );

        final deps = await AppDependencies.test(
          db: db,
          userSettings: userSettings,
          userHealthMetrics: UserHealthMetricsRepository(db, clock: clock),
          timeProvider: clock,
          ingestionSources: [PhonePedometerSource(), const AdpBleSource()],
        );

        expect(deps.timeProvider, same(clock));
        expect(deps.stepNormalizer, isA<StepNormalizer>());
        expect(deps.stepNormalizer.clock, same(clock));
        expect(deps.stepRepository, isA<StepRepository>());
        expect(deps.stepRepository.clock, same(clock));
        expect(deps.backgroundCollector, isA<BackgroundCollector>());
        expect(deps.liveStepMonitor, isA<LiveStepMonitor>());
        expect(deps.dataLifecycleService, isA<DataLifecycleService>());
        expect(deps.databasePath, inMemoryDatabasePath);
        expect(deps.notificationService, isA<NotificationService>());
        expect(deps.ingestionSources, hasLength(2));
        expect(deps.ingestionSources, contains(isA<PhonePedometerSource>()));
        expect(deps.ingestionSources, contains(isA<AdpBleSource>()));

        final defaultDeps = await AppDependencies.test(
          db: db,
          userSettings: userSettings,
          userHealthMetrics: userHealthMetrics,
          timeProvider: clock,
        );
        expect(
          defaultDeps.ingestionSources,
          contains(isA<MonitorDrainSource>()),
        );
      },
    );

  });
}
