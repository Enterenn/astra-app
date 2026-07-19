@Tags(['critical'])
library;

import 'dart:async';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/coordinators/app_cubit_coordinator.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/coordinator_unit_test_deps.dart';
import '../../helpers/sqflite_test_helper.dart';

class _SpyTodayCubit extends TodayCubit {
  _SpyTodayCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
  }) : super(activityPermissionGranted: () async => true);

  final refreshCalls = <bool>[];
  final syncStepsCalls = <int>[];
  final refreshMetadataCalls = <void>[];

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCalls.add(silent);
  }

  @override
  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) async {
    syncStepsCalls.add(steps);
  }

  @override
  Future<void> refreshMetadata() async {
    refreshMetadataCalls.add(null);
  }
}

class _SpyHistoryCubit extends HistoryCubit {
  _SpyHistoryCubit({
    required super.stepAggregation,
    required super.userHealthMetrics,
  });

  int refreshCallCount = 0;
  int refreshGoalCallCount = 0;

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCallCount++;
  }

  @override
  Future<void> refreshGoal() async {
    refreshGoalCallCount++;
  }
}

class _SpyMyDataCubit extends MyDataCubit {
  _SpyMyDataCubit({
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.databasePath,
    required super.activityPermissionGranted,
  }) : super(
         pickCsvFile: () async => null,
         saveCsvFile: (_) async => false,
       );

  final refreshCalls = <bool>[];

  @override
  Future<void> refresh({bool silent = true}) async {
    refreshCalls.add(silent);
  }
}

class _TrackingLiveStepMonitor extends LiveStepMonitor {
  _TrackingLiveStepMonitor({
    required super.stepAggregation,
    required super.baselineRepository,
    required super.clock,
    required super.stepEventStreamFactory,
    this.reconcileSteps = 4200,
  });

  final int reconcileSteps;
  int reconcileCallCount = 0;

  @override
  int get currentTodaySteps => reconcileSteps;

  @override
  Future<void> reconcileFromDatabase({int? seedPersistedSteps}) async {
    reconcileCallCount++;
  }
}

class _BlockingTodayCubit extends TodayCubit {
  _BlockingTodayCubit({
    required super.stepAggregation,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required this.onRefresh,
  }) : super(activityPermissionGranted: () async => true);

  final Completer<void> Function() onRefresh;

  @override
  Future<void> refresh({bool silent = true}) async {
    await onRefresh().future;
  }

  @override
  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) async {}

  @override
  Future<void> refreshMetadata() async {}
}

FakeTimeProvider _testClock() => FakeTimeProvider(
  fixedNowUtc: DateTime.utc(2026, 6, 19, 12),
  zoneOffset: Duration.zero,
);

AppCubitCoordinator _coordinatorWithSpies({
  required AppDependencies deps,
  _SpyTodayCubit? today,
  _SpyHistoryCubit? history,
  _SpyMyDataCubit? myData,
}) {
  return AppCubitCoordinator(
    deps: deps,
    createTodayCubit: (d) =>
        today ??
        _SpyTodayCubit(
          stepAggregation: d.stepAggregation,
          userSettings: d.userSettings,
          userHealthMetrics: d.userHealthMetrics,
          clock: d.timeProvider,
        ),
    createHistoryCubit: (d) =>
        history ??
        _SpyHistoryCubit(
          stepAggregation: d.stepAggregation,
          userHealthMetrics: d.userHealthMetrics,
        ),
    createMyDataCubit: (d) =>
        myData ??
        _SpyMyDataCubit(
          stepAggregation: d.stepAggregation,
          csvService: d.csvService,
          stepIngestion: d.stepIngestion,
          userSettings: d.userSettings,
          userHealthMetrics: d.userHealthMetrics,
          clock: d.timeProvider,
          databasePath: d.databasePath,
          activityPermissionGranted: d.activityPermissionGranted,
        ),
    createProfileCubit: (d) => ProfileCubit(
      userSettings: d.userSettings,
      userHealthMetrics: d.userHealthMetrics,
      notificationService: d.notificationService,
    ),
  );
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AppCubitCoordinator', () {
    test('ensureHistory lazily creates history cubit once', () {
      final deps = buildCoordinatorUnitTestDeps(timeProvider: _testClock());
      final coordinator = _coordinatorWithSpies(deps: deps);
      addTearDown(coordinator.dispose);

      expect(coordinator.historyIfCreated, isNull);

      final first = coordinator.ensureHistory();
      final second = coordinator.ensureHistory();

      expect(identical(first, second), isTrue);
      expect(coordinator.historyIfCreated, same(first));
    });

    group('with sqlite deps', () {
      late Database db;
      late AppDependencies deps;

      setUp(() async {
        db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
        final clock = _testClock();
        final userSettings = UserSettingsRepository(db);
        await userSettings.setOnboardingComplete(true);
        final userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
        deps = await AppDependencies.test(
          db: db,
          userSettings: userSettings,
          userHealthMetrics: userHealthMetrics,
          timeProvider: clock,
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('refreshAfterPurge runs phases in order', () async {
        final monitor = _TrackingLiveStepMonitor(
          stepAggregation: deps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(deps.databaseSession),
          clock: deps.timeProvider,
          stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
          reconcileSteps: 5100,
        );
        final testDeps = await AppDependencies.test(
          db: db,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          timeProvider: deps.timeProvider,
          liveStepMonitor: monitor,
        );
        final today = _SpyTodayCubit(
          stepAggregation: testDeps.stepAggregation,
          userSettings: testDeps.userSettings,
          userHealthMetrics: testDeps.userHealthMetrics,
          clock: testDeps.timeProvider,
        );
        final history = _SpyHistoryCubit(
          stepAggregation: testDeps.stepAggregation,
          userHealthMetrics: testDeps.userHealthMetrics,
        );
        final myData = _SpyMyDataCubit(
          stepAggregation: testDeps.stepAggregation,
          csvService: testDeps.csvService,
          stepIngestion: testDeps.stepIngestion,
          userSettings: testDeps.userSettings,
          userHealthMetrics: testDeps.userHealthMetrics,
          clock: testDeps.timeProvider,
          databasePath: testDeps.databasePath,
          activityPermissionGranted: testDeps.activityPermissionGranted,
        );

        final coordinator = AppCubitCoordinator(
          deps: testDeps,
          createTodayCubit: (_) => today,
          createHistoryCubit: (_) => history,
          createMyDataCubit: (_) => myData,
          createProfileCubit: (d) => ProfileCubit(
            userSettings: d.userSettings,
            userHealthMetrics: d.userHealthMetrics,
            notificationService: d.notificationService,
          ),
        );
        addTearDown(coordinator.dispose);

        await coordinator.refreshAfterPurge();

        expect(monitor.reconcileCallCount, 1);
        expect(today.refreshCalls, [true]);
        expect(today.syncStepsCalls, [5100]);
        expect(today.refreshMetadataCalls.length, 1);
        expect(history.refreshCallCount, 1);
        expect(myData.refreshCalls, [true]);
      });

      test('refreshAfterPurge stops after dispose mid-flight', () async {
        final refreshGate = Completer<void>();
        final today = _BlockingTodayCubit(
          stepAggregation: deps.stepAggregation,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          clock: deps.timeProvider,
          onRefresh: () => refreshGate,
        );
        final history = _SpyHistoryCubit(
          stepAggregation: deps.stepAggregation,
          userHealthMetrics: deps.userHealthMetrics,
        );
        final myData = _SpyMyDataCubit(
          stepAggregation: deps.stepAggregation,
          csvService: deps.csvService,
          stepIngestion: deps.stepIngestion,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          clock: deps.timeProvider,
          databasePath: deps.databasePath,
          activityPermissionGranted: deps.activityPermissionGranted,
        );

        final coordinator = AppCubitCoordinator(
          deps: deps,
          createTodayCubit: (_) => today,
          createHistoryCubit: (_) => history,
          createMyDataCubit: (_) => myData,
          createProfileCubit: (d) => ProfileCubit(
            userSettings: d.userSettings,
            userHealthMetrics: d.userHealthMetrics,
            notificationService: d.notificationService,
          ),
        );

        final purgeFuture = coordinator.refreshAfterPurge();
        await Future<void>.delayed(Duration.zero);
        coordinator.dispose();
        refreshGate.complete();
        await purgeFuture;

        expect(history.refreshCallCount, 0);
        expect(myData.refreshCalls, isEmpty);
      });

      test('today goal update propagates to history and my data', () async {
        final history = _SpyHistoryCubit(
          stepAggregation: deps.stepAggregation,
          userHealthMetrics: deps.userHealthMetrics,
        );
        final myData = _SpyMyDataCubit(
          stepAggregation: deps.stepAggregation,
          csvService: deps.csvService,
          stepIngestion: deps.stepIngestion,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          clock: deps.timeProvider,
          databasePath: deps.databasePath,
          activityPermissionGranted: deps.activityPermissionGranted,
        );
        final coordinator = AppCubitCoordinator(
          deps: deps,
          createHistoryCubit: (_) => history,
          createMyDataCubit: (_) => myData,
          createProfileCubit: (d) => ProfileCubit(
            userSettings: d.userSettings,
            userHealthMetrics: d.userHealthMetrics,
            notificationService: d.notificationService,
          ),
        );
        addTearDown(coordinator.dispose);

        coordinator.ensureHistory();
        final updated = await coordinator.today.updateDailyStepGoal(9000);

        expect(updated, isTrue);
        expect(history.refreshGoalCallCount, 1);
        expect(myData.refreshCalls, [true]);
      });
    });

    test('onIngestionComplete refreshes history only when tab active', () {
      final deps = buildCoordinatorUnitTestDeps(timeProvider: _testClock());
      final history = _SpyHistoryCubit(
        stepAggregation: deps.stepAggregation,
        userHealthMetrics: deps.userHealthMetrics,
      );
      final coordinator = _coordinatorWithSpies(deps: deps, history: history);
      addTearDown(coordinator.dispose);

      coordinator.onIngestionComplete(historyTabActive: false);
      expect(history.refreshCallCount, 0);

      coordinator.ensureHistory();
      coordinator.onIngestionComplete(historyTabActive: true);
      expect(history.refreshCallCount, 1);
    });

    test('onReturnToToday always refreshes metadata; goal only if history exists', () {
      final deps = buildCoordinatorUnitTestDeps(timeProvider: _testClock());
      final today = _SpyTodayCubit(
        stepAggregation: deps.stepAggregation,
        userSettings: deps.userSettings,
        userHealthMetrics: deps.userHealthMetrics,
        clock: deps.timeProvider,
      );
      final history = _SpyHistoryCubit(
        stepAggregation: deps.stepAggregation,
        userHealthMetrics: deps.userHealthMetrics,
      );
      final coordinator = AppCubitCoordinator(
        deps: deps,
        createTodayCubit: (_) => today,
        createHistoryCubit: (_) => history,
        createMyDataCubit: (d) => _SpyMyDataCubit(
          stepAggregation: d.stepAggregation,
          csvService: d.csvService,
          stepIngestion: d.stepIngestion,
          userSettings: d.userSettings,
          userHealthMetrics: d.userHealthMetrics,
          clock: d.timeProvider,
          databasePath: d.databasePath,
          activityPermissionGranted: d.activityPermissionGranted,
        ),
        createProfileCubit: (d) => ProfileCubit(
          userSettings: d.userSettings,
          userHealthMetrics: d.userHealthMetrics,
          notificationService: d.notificationService,
        ),
      );
      addTearDown(coordinator.dispose);

      coordinator.onReturnToToday();
      expect(today.refreshMetadataCalls.length, 1);
      expect(history.refreshGoalCallCount, 0);

      coordinator.ensureHistory();
      coordinator.onReturnToToday();
      expect(today.refreshMetadataCalls.length, 2);
      expect(history.refreshGoalCallCount, 1);
    });
  });
}
