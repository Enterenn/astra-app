import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/datasources/adp_ble_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
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
    late UserPreferencesRepository userPreferences;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
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
          userPreferences: userPreferences,
          timeProvider: clock,
        );

        expect(deps.timeProvider, same(clock));
        expect(deps.stepNormalizer, isA<StepNormalizer>());
        expect(deps.stepNormalizer.clock, same(clock));
        expect(deps.ingestionSources, hasLength(2));
        expect(deps.ingestionSources, contains(isA<PhonePedometerSource>()));
        expect(deps.ingestionSources, contains(isA<AdpBleSource>()));
      },
    );
  });
}
