import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/database_footprint.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _FixedCapabilityEvaluator extends BackgroundHealthCapabilityEvaluator {
  _FixedCapabilityEvaluator(this._snapshot)
    : super(
        activityRecognitionGranted: () async => _snapshot.activityRecognitionGranted,
        notificationGranted: () async => _snapshot.notificationGranted,
        isAndroidPlatform: () => true,
      );

  final BackgroundHealthCapabilitySnapshot _snapshot;

  @override
  Future<BackgroundHealthCapabilitySnapshot> evaluate() async => _snapshot;
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    MyDataCubit buildCubit({
      BackgroundHealthCapabilitySnapshot? snapshot,
      Future<bool> Function()? activityPermissionGranted,
      bool isIos = false,
    }) {
      return MyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(
          snapshot ??
              const BackgroundHealthCapabilitySnapshot(
                activityRecognitionGranted: true,
                notificationGranted: true,
                batteryOptimizationExempt: true,
                fgsHealthDeclared: true,
                likelyOemBatteryDeferral: false,
              ),
        ),
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
      await stepRepository.upsertIngestionBucket(
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
      await stepRepository.upsertIngestionBucket(
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
      await stepRepository.upsertIngestionBucket(
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
      await stepRepository.upsertIngestionBucket(
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
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      await stepRepository.upsertIngestionBucket(
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

    test('refresh includes lastOptimized when preference is set', () async {
      await userPreferences.setLastDatabaseOptimizedAt(
        DateTime.utc(2026, 6, 3, 11, 30),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.lastOptimizedUtc, DateTime.utc(2026, 6, 3, 11, 30));
      cubit.close();
    });

    test('refresh leaves lastOptimized null when never optimized', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.lastOptimizedUtc, isNull);
      cubit.close();
    });

    test('refresh emits ready defaults when first load fails', () async {
      final failingRepository = _ThrowingFootprintRepository(
        db: db,
        clock: clock,
      );
      final cubit = MyDataCubit(
        stepRepository: failingRepository,
        userPreferences: userPreferences,
        activityPermissionGranted: () async => true,
        capabilityEvaluator: _FixedCapabilityEvaluator(
          const BackgroundHealthCapabilitySnapshot(
            activityRecognitionGranted: true,
            notificationGranted: true,
            batteryOptimizationExempt: true,
            fgsHealthDeclared: true,
            likelyOemBatteryDeferral: false,
          ),
        ),
        clock: clock,
        databasePath: inMemoryDatabasePath,
        isIos: false,
      );

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.sampleCount, 0);
      expect(cubit.state.backgroundStatus, BackgroundCollectionStatus.healthy);
      cubit.close();
    });

    test('refresh keeps last ready snapshot when silent refresh fails', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      final flakyRepository = _FlakyFootprintRepository(db: db, clock: clock);
      final cubit = MyDataCubit(
        stepRepository: flakyRepository,
        userPreferences: userPreferences,
        activityPermissionGranted: () async => true,
        capabilityEvaluator: _FixedCapabilityEvaluator(
          const BackgroundHealthCapabilitySnapshot(
            activityRecognitionGranted: true,
            notificationGranted: true,
            batteryOptimizationExempt: true,
            fgsHealthDeclared: true,
            likelyOemBatteryDeferral: false,
          ),
        ),
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

class _ThrowingFootprintRepository extends StepRepository {
  _ThrowingFootprintRepository({required super.db, required super.clock});

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async {
    throw StateError('footprint unavailable');
  }
}

class _FlakyFootprintRepository extends StepRepository {
  _FlakyFootprintRepository({required super.db, required super.clock});

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
