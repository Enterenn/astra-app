import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme_preference.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
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

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';
import '../time/fake_time_provider.dart';
import 'package:astra_app/data/services/csv_service.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';

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
        expect(deps.stepIngestion, isA<StepIngestionRepository>());
        expect(deps.stepAggregation, isA<StepAggregationRepository>());
        expect(deps.csvService, isA<CsvService>());
        expect(deps.stepAggregation.clock, same(clock));
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

  group('initial preference batch load', () {
    late Database db;
    late UserSettingsRepository userSettings;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('AppDependencies.test reflects seeded prefs', () async {
      await userSettings.setThemeMode(AstraThemePreference.dark);
      await userSettings.setAccentPreset(AstraAccentPreset.pink);
      await userSettings.setDistanceDisplayUnit(DistanceDisplayUnit.imperial);
      await userSettings.setWeightDisplayUnit(WeightDisplayUnit.lb);
      await userSettings.setHeightDisplayUnit(HeightDisplayUnit.ftIn);
      await userSettings.setOnboardingComplete(true);
      await userSettings.setAppLocale('fr');

      final deps = await AppDependencies.test(
        db: db,
        userSettings: userSettings,
      );

      expect(deps.initialTheme, AstraThemePreference.dark);
      expect(deps.initialAccentPreset, AstraAccentPreset.pink);
      expect(deps.initialDistanceUnit, DistanceDisplayUnit.imperial);
      expect(deps.initialWeightUnit, WeightDisplayUnit.lb);
      expect(deps.initialHeightUnit, HeightDisplayUnit.ftIn);
      expect(deps.initialOnboardingComplete, isTrue);
      expect(deps.initialAppLocale, 'fr');
    });

    test('AppDependencies.test uses defaults on empty DB', () async {
      final deps = await AppDependencies.test(
        db: db,
        userSettings: userSettings,
      );

      expect(deps.initialTheme, AstraThemePreference.system);
      expect(deps.initialAccentPreset, AstraAccentPreset.orange);
      expect(deps.initialDistanceUnit, DistanceDisplayUnit.metric);
      expect(deps.initialWeightUnit, WeightDisplayUnit.kg);
      expect(deps.initialHeightUnit, HeightDisplayUnit.cm);
      expect(deps.initialOnboardingComplete, isFalse);
      expect(deps.initialAppLocale, isNull);
    });

    test('onboarding override skips DB read', () async {
      await userSettings.setOnboardingComplete(false);

      final deps = await AppDependencies.test(
        db: db,
        userSettings: userSettings,
        initialOnboardingComplete: true,
      );

      expect(deps.initialOnboardingComplete, isTrue);
    });
  });
}
