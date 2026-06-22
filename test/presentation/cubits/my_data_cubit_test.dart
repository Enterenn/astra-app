import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/database_footprint.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import 'package:astra_app/core/time/time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late FakeTimeProvider clock;
    late StepTestRepos stepRepos;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    MyDataCubit buildCubit({
      Future<bool> Function()? activityPermissionGranted,
      bool isIos = false,
    }) {
      return MyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted:
            activityPermissionGranted ?? () async => true,
        isIos: isIos,
      );
    }

    test('starts in loading state', () {
      final cubit = buildCubit();
      expect(cubit.state.status, MyDataStatus.loading);
      cubit.close();
    });

    test('refresh emits permissionDenied when activity permission denied', () async {
      final cubit = buildCubit(activityPermissionGranted: () async => false);

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(
        cubit.state.backgroundStatus,
        BackgroundCollectionStatus.permissionDenied,
      );
      cubit.close();
    });

    test('refresh emits healthy Android when recent ingestion exists', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      final cubit = buildCubit(isIos: false);

      await cubit.refresh();

      expect(cubit.state.backgroundStatus, BackgroundCollectionStatus.healthy);
      expect(cubit.state.isIos, isFalse);
      cubit.close();
    });

    test('refresh emits stale Android when last ingestion exceeds 12h', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 20),
          endTimeUtc: DateTime.utc(2026, 6, 2, 20, 5),
        ),
      );
      final cubit = buildCubit(isIos: false);

      await cubit.refresh();

      expect(cubit.state.backgroundStatus, BackgroundCollectionStatus.stale);
      expect(cubit.state.isStale, isTrue);
      cubit.close();
    });

    test('refresh emits stale iOS when last ingestion exceeds 4h', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 6),
          endTimeUtc: DateTime.utc(2026, 6, 3, 6, 5),
        ),
      );
      final cubit = buildCubit(isIos: true);

      await cubit.refresh();

      expect(cubit.state.backgroundStatus, BackgroundCollectionStatus.stale);
      cubit.close();
    });

    test('refresh emits iosBackfill when iOS ingestion is recent', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 11),
          endTimeUtc: DateTime.utc(2026, 6, 3, 11, 5),
        ),
      );
      final cubit = buildCubit(isIos: true);

      await cubit.refresh();

      expect(
        cubit.state.backgroundStatus,
        BackgroundCollectionStatus.iosBackfill,
      );
      cubit.close();
    });

    test('refresh includes footprint sample count after inject', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 10),
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.sampleCount, 2);
      expect(cubit.state.fileSizeBytes, 0);
      cubit.close();
    });

    test('refresh emits stale (not healthy) when first load fails', () async {
      final failingRepository = _ThrowingFootprintRepository(
        db: db,
        clock: clock,
      );
      final cubit = MyDataCubit(
        stepAggregation: failingRepository,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        activityPermissionGranted: () async => true,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        isIos: false,
      );

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.sampleCount, 0);
      // Fallback must signal degraded state (stale), not healthy.
      expect(cubit.state.backgroundStatus, BackgroundCollectionStatus.stale);
      cubit.close();
    });

    test('refresh keeps last ready snapshot when silent refresh fails', () async {
      await stepRepos.ingestion.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      final flakyRepository = _FlakyFootprintRepository(db: db, clock: clock);
      final cubit = MyDataCubit(
        stepAggregation: flakyRepository,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        activityPermissionGranted: () async => true,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        isIos: false,
      );

      await cubit.refresh();
      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.sampleCount, 1);

      flakyRepository.failOnNextFootprint();
      await cubit.refresh(silent: true);

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.sampleCount, 1);
      cubit.close();
    });
  });
}

class _ThrowingFootprintRepository extends StepAggregationRepository {
  _ThrowingFootprintRepository({required Database db, required TimeProvider clock})
      : super(db, clock: clock);

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async {
    throw StateError('footprint unavailable');
  }
}

class _FlakyFootprintRepository extends StepAggregationRepository {
  _FlakyFootprintRepository({required Database db, required TimeProvider clock})
      : super(db, clock: clock);

  var _failFootprint = false;

  void failOnNextFootprint() {
    _failFootprint = true;
  }

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async {
    if (_failFootprint) {
      throw StateError('footprint unavailable');
    }
    return super.getFootprint(databasePath: databasePath);
  }
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required DateTime endTimeUtc,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: endTimeUtc,
  value: 100,
  provider: kInternalPhoneProvider,
  deviceId: kSmartphoneDeviceId,
  zoneOffset: '+02:00',
);
