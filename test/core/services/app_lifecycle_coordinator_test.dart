import 'dart:async';

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/app_lifecycle_coordinator.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/contracts/contracts.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/data/models/database_footprint.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/coordinator_unit_test_deps.dart';
import '../../helpers/recording_health_fgs.dart';
import '../time/fake_time_provider.dart';

class _ColdStartStepAggregation implements StepAggregationRepositoryContract {
  _ColdStartStepAggregation(this.clock);

  @override
  final TimeProvider clock;

  @override
  Future<int> getTodaySteps() async => 1200;

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async => [];

  @override
  Future<DateTime?> getLastIngestionUtc() async => null;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async =>
      List.generate(
        days,
        (index) => ChartDayAggregate(
          localDay: DateTime.utc(2026, 6, 19).subtract(Duration(days: index)),
          totalSteps: 0,
        ),
      );

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

/// Wraps a fixed step count and tracks getTodaySteps call count for AUD-03 assertions.
/// Returns [beforeBackfill] until [backfillComplete], then [afterBackfill].
class _BackfillGatedStepAggregation implements StepAggregationRepositoryContract {
  _BackfillGatedStepAggregation(
    this.clock, {
    this.beforeBackfill = 1200,
    this.afterBackfill = 1500,
  });

  @override
  final TimeProvider clock;

  final int beforeBackfill;
  final int afterBackfill;
  bool backfillComplete = false;

  @override
  Future<int> getTodaySteps() async =>
      backfillComplete ? afterBackfill : beforeBackfill;

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async => [];

  @override
  Future<DateTime?> getLastIngestionUtc() async => null;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async =>
      [];

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

class _CountingStepAggregation implements StepAggregationRepositoryContract {
  _CountingStepAggregation(this.clock, {this.stubbedSteps = 1200});

  @override
  final TimeProvider clock;

  final int stubbedSteps;
  int getTodayStepsCallCount = 0;

  @override
  Future<int> getTodaySteps() async {
    getTodayStepsCallCount++;
    return stubbedSteps;
  }

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async => [];

  @override
  Future<DateTime?> getLastIngestionUtc() async => null;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async =>
      [];

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

class _ColdStartUserSettings implements UserSettingsRepositoryContract {
  @override
  bool get isDatabaseOpen => true;

  @override
  Future<int?> getLastDisplayedSteps(String localDayIso) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ColdStartUserHealthMetrics implements UserHealthMetricsRepositoryContract {
  @override
  Future<int> getGoalForLocalDay(String localDayIso) async => kDefaultStepGoal;

  @override
  Future<Map<String, int>> getGoalsForLocalDays(
    List<String> localDayIsos,
  ) async =>
      {for (final iso in localDayIsos) iso: kDefaultStepGoal};

  @override
  Future<int?> getHeightCm() async => null;

  @override
  Future<double?> getWeightKg() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Wraps a [LiveStepMonitor] and captures the seed values passed to start/reconcile.
class _SeedCapturingMonitor extends LiveStepMonitor {
  _SeedCapturingMonitor({
    required LiveStepMonitor inner,
    required void Function(int?) onStart,
    required void Function(int?) onReconcile,
  })  : _onStart = onStart,
        _onReconcile = onReconcile,
        super(
          stepAggregation: inner.stepAggregation,
          baselineRepository: inner.baselineRepository,
          clock: inner.clock,
          stepEventStreamFactory: () => const Stream.empty(),
          emitThrottle: Duration.zero,
        );

  final void Function(int?) _onStart;
  final void Function(int?) _onReconcile;

  @override
  Future<void> start({int? seedPersistedSteps}) async {
    _onStart(seedPersistedSteps);
    return super.start(seedPersistedSteps: seedPersistedSteps);
  }

  @override
  Future<void> reconcileFromDatabase({int? seedPersistedSteps}) async {
    _onReconcile(seedPersistedSteps);
    return super.reconcileFromDatabase(seedPersistedSteps: seedPersistedSteps);
  }
}

class _DelayingBackgroundCollector extends BackgroundCollector {
  _DelayingBackgroundCollector({
    required super.sources,
    required super.normalizer,
    required super.repository,
    required super.stepAggregation,
    required super.baselineRepository,
    required this.collectDelay,
    required this.onCollectStart,
    required this.onCollectEnd,
  });

  final Duration collectDelay;
  final void Function() onCollectStart;
  final void Function() onCollectEnd;

  @override
  Future<int> collectOnce({
    int maxReadingsPerSource = 50,
    bool enableGoalNotification = false,
    Duration? sourceTimeout,
  }) async {
    onCollectStart();
    await Future<void>.delayed(collectDelay);
    onCollectEnd();
    return 0;
  }
}

class _NoOpBackgroundCollector extends BackgroundCollector {
  _NoOpBackgroundCollector({
    required super.sources,
    required super.normalizer,
    required super.repository,
    required super.stepAggregation,
    required super.baselineRepository,
  });

  @override
  Future<int> collectOnce({
    int maxReadingsPerSource = 50,
    bool enableGoalNotification = false,
    Duration? sourceTimeout,
  }) async =>
      0;
}

class _SourceTimeoutCapturingBackgroundCollector extends BackgroundCollector {
  _SourceTimeoutCapturingBackgroundCollector({
    required super.sources,
    required super.normalizer,
    required super.repository,
    required super.stepAggregation,
    required super.baselineRepository,
  });

  final List<Duration?> capturedTimeouts = [];

  @override
  Future<int> collectOnce({
    int maxReadingsPerSource = 50,
    bool enableGoalNotification = false,
    Duration? sourceTimeout,
  }) async {
    capturedTimeouts.add(sourceTimeout);
    return 0;
  }
}

Future<AppLifecycleCoordinator> _boundCoordinator(
  AppDependencies deps, {
  bool enableLiveStepPipeline = false,
}) async {
  final coordinator = deps.appLifecycleCoordinator;
  coordinator.bindToWidget(
    isMounted: () => true,
    showMainShell: () => true,
    enablePeriodicPersist: false,
    enableLiveStepPipeline: enableLiveStepPipeline,
    maxPersistStaleness: const Duration(seconds: 1),
    minPauseForPhoneCatchUp: const Duration(seconds: 10),
    initialShowMainShell: true,
  );
  await coordinator.foregroundBackfill;
  return coordinator;
}

void main() {
  group('AppLifecycleCoordinator', () {
    late FakeTimeProvider clock;

    setUp(() {
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 19, 10),
        zoneOffset: const Duration(hours: 2),
      );
    });

    test('enqueuePersistCycle serializes overlapping calls', () async {
      var concurrent = 0;
      var maxConcurrent = 0;

      final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
      final delayingCollector = _DelayingBackgroundCollector(
        sources: seedDeps.ingestionSources,
        normalizer: seedDeps.stepNormalizer,
        repository: seedDeps.stepIngestion,
        stepAggregation: seedDeps.stepAggregation,
        baselineRepository: IngestionBaselineRepository(
          seedDeps.databaseSession,
        ),
        collectDelay: const Duration(milliseconds: 50),
        onCollectStart: () {
          concurrent++;
          if (concurrent > maxConcurrent) {
            maxConcurrent = concurrent;
          }
        },
        onCollectEnd: () {
          concurrent--;
        },
      );

      final deps = buildCoordinatorUnitTestDeps(
        timeProvider: clock,
        backgroundCollector: delayingCollector,
      );
      final coordinator = await _boundCoordinator(deps);

      await Future.wait([
        coordinator.enqueuePersistCycleForTest(enableGoalNotification: false),
        coordinator.enqueuePersistCycleForTest(enableGoalNotification: false),
      ]);

      expect(maxConcurrent, 1);
    });

    test('runLocalDayBoundaryIfNeeded no-ops when local day unchanged', () async {
      final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
      final deps = buildCoordinatorUnitTestDeps(
        timeProvider: clock,
        backgroundCollector: _NoOpBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
        ),
      );
      final coordinator = await _boundCoordinator(
        deps,
        enableLiveStepPipeline: true,
      );

      await coordinator.runLocalDayBoundaryIfNeededForTest();
      final stepsBefore = await deps.stepAggregation.getTodaySteps();

      await coordinator.runLocalDayBoundaryIfNeededForTest();

      final stepsAfter = await deps.stepAggregation.getTodaySteps();
      expect(stepsAfter, stepsBefore);
    });

    test('onLifecycleStatePaused hands off to health FGS when shell visible', () async {
      final calls = <String>[];
      final fgs = RecordingHealthFgs(calls: calls);
      final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
      final deps = buildCoordinatorUnitTestDeps(
        timeProvider: clock,
        healthForegroundCoordinator: fgs,
        backgroundCollector: _NoOpBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
        ),
      );
      final coordinator = await _boundCoordinator(deps);

      await coordinator.onLifecycleStatePaused();

      expect(calls, contains('uiActive:false'));
      expect(calls, contains('start'));
    });

    group('onTodayCubitReady', () {
      test(
        'onTodayCubitReady runs refreshFastPath before backfill completes',
        () async {
        final events = <String>[];
        final backfillDone = Completer<void>();

        // Created before the collector so closures capture a non-null reference.
        final todayCubit = TodayCubit(
          stepAggregation: _ColdStartStepAggregation(clock),
          userSettings: _ColdStartUserSettings(),
          userHealthMetrics: _ColdStartUserHealthMetrics(),
          clock: clock,
          activityPermissionGranted: () async => true,
        );
        todayCubit.stream.listen((state) {
          if (state.lastDisplayedStepsLoaded && !events.contains('fast_path')) {
            events.add('fast_path');
          }
        });

        final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
        final delayingCollector = _DelayingBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
          collectDelay: const Duration(milliseconds: 150),
          onCollectStart: () => events.add('backfill_start'),
          onCollectEnd: () {
            expect(
              todayCubit.state.lastDisplayedStepsLoaded,
              isTrue,
              reason: 'refreshFastPath must emit before backfill ends',
            );
            expect(todayCubit.state.status, isNot(TodayStatus.loading));
            events.add('backfill_end');
            if (!backfillDone.isCompleted) {
              backfillDone.complete();
            }
          },
        );

        final deps = buildCoordinatorUnitTestDeps(
          timeProvider: clock,
          backgroundCollector: delayingCollector,
        );
        final coordinator = deps.appLifecycleCoordinator;
        coordinator.bindToWidget(
          isMounted: () => true,
          showMainShell: () => true,
          enablePeriodicPersist: false,
          enableLiveStepPipeline: true,
          maxPersistStaleness: const Duration(seconds: 1),
          minPauseForPhoneCatchUp: const Duration(seconds: 10),
          initialShowMainShell: true,
        );

        coordinator.onTodayCubitReady(todayCubit);

        await backfillDone.future.timeout(const Duration(seconds: 2));
        await pumpEventQueue();

        expect(
          events.indexOf('fast_path'),
          lessThan(events.indexOf('backfill_end')),
        );
        expect(todayCubit.state.lastDisplayedStepsLoaded, isTrue);
        expect(todayCubit.state.status, isNot(TodayStatus.loading));

        await todayCubit.close();
        },
      );

      test(
        'onTodayCubitReady binds monitor with fast-path seed without extra getTodaySteps on bind',
        () async {
        // The coordinator must pass cubit.state.steps as seed on skipSqliteRefresh
        // cold bind. start() always receives the seed (called once). reconcileFromDatabase()
        // may be called multiple times (persist cycle + bind + post-backfill); at least
        // one call must carry the fast-path seed.
        int? capturedStartSeed;
        final capturedReconcileSeeds = <int?>[];
        final bindDone = Completer<void>();

        final counting = _CountingStepAggregation(clock, stubbedSteps: 1200);

        final todayCubit = TodayCubit(
          stepAggregation: counting,
          userSettings: _ColdStartUserSettings(),
          userHealthMetrics: _ColdStartUserHealthMetrics(),
          clock: clock,
          activityPermissionGranted: () async => true,
        );

        final baselineRepo = IngestionBaselineRepository(
          CoordinatorStubDatabase(),
        );
        final innerMonitor = LiveStepMonitor(
          stepAggregation: counting,
          baselineRepository: baselineRepo,
          clock: clock,
          stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
        );
        final captureMonitor = _SeedCapturingMonitor(
          inner: innerMonitor,
          onStart: (seed) {
            capturedStartSeed = seed;
            if (!bindDone.isCompleted) bindDone.complete();
          },
          onReconcile: (seed) => capturedReconcileSeeds.add(seed),
        );

        final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
        // Delay backfill collect so parallel _runPersistCycle cannot reconcile
        // before bind completes — isolates bind-path dedup from AC #4 race.
        final delayingCollector = _DelayingBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
          collectDelay: const Duration(milliseconds: 500),
          onCollectStart: () {},
          onCollectEnd: () {},
        );
        final deps = buildCoordinatorUnitTestDeps(
          timeProvider: clock,
          liveStepMonitor: captureMonitor,
          backgroundCollector: delayingCollector,
        );

        final coordinator = deps.appLifecycleCoordinator;
        coordinator.bindToWidget(
          isMounted: () => true,
          showMainShell: () => true,
          enablePeriodicPersist: false,
          enableLiveStepPipeline: true,
          maxPersistStaleness: const Duration(seconds: 1),
          minPauseForPhoneCatchUp: const Duration(seconds: 10),
          initialShowMainShell: true,
        );
        coordinator.onTodayCubitReady(todayCubit);

        await bindDone.future.timeout(const Duration(seconds: 2));
        await pumpEventQueue();

        // AC #5: only refreshFastPath reads getTodaySteps before monitor bind/syncSteps.
        expect(
          counting.getTodayStepsCallCount,
          1,
          reason: 'bind path must not add getTodaySteps beyond fast path',
        );

        await coordinator.foregroundBackfill;
        await pumpEventQueue();

        // start() is only called once (cold bind) and must carry the fast-path seed.
        expect(capturedStartSeed, 1200,
            reason: 'monitor.start must receive fast-path steps as seed');
        // Among all reconcileFromDatabase calls, the cold-bind one must carry the seed.
        expect(capturedReconcileSeeds, contains(1200),
            reason: 'cold bind reconcile must receive same seed');
        expect(todayCubit.state.steps, 1200);
        // Post-backfill: persist-cycle reconcile + _reconcileAfterBackfillCompletes.
        expect(counting.getTodayStepsCallCount, greaterThan(1));

        await todayCubit.close();
        await captureMonitor.dispose();
        },
      );

      test(
        'onTodayCubitReady reconciles after foregroundBackfill completes',
        () async {
          var backfillEnded = false;
          var postBackfillReconcileSeen = false;
          final backfillDone = Completer<void>();

          final steps = _BackfillGatedStepAggregation(clock);
          final todayCubit = TodayCubit(
            stepAggregation: steps,
            userSettings: _ColdStartUserSettings(),
            userHealthMetrics: _ColdStartUserHealthMetrics(),
            clock: clock,
            activityPermissionGranted: () async => true,
          );

          final baselineRepo = IngestionBaselineRepository(
            CoordinatorStubDatabase(),
          );
          final innerMonitor = LiveStepMonitor(
            stepAggregation: steps,
            baselineRepository: baselineRepo,
            clock: clock,
            stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
          );
          final captureMonitor = _SeedCapturingMonitor(
            inner: innerMonitor,
            onStart: (_) {},
            onReconcile: (_) {
              if (backfillEnded) {
                postBackfillReconcileSeen = true;
              }
            },
          );

          final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
          final delayingCollector = _DelayingBackgroundCollector(
            sources: seedDeps.ingestionSources,
            normalizer: seedDeps.stepNormalizer,
            repository: seedDeps.stepIngestion,
            stepAggregation: seedDeps.stepAggregation,
            baselineRepository: IngestionBaselineRepository(
              seedDeps.databaseSession,
            ),
            collectDelay: const Duration(milliseconds: 150),
            onCollectStart: () {},
            onCollectEnd: () {
              backfillEnded = true;
              steps.backfillComplete = true;
              if (!backfillDone.isCompleted) {
                backfillDone.complete();
              }
            },
          );
          final deps = buildCoordinatorUnitTestDeps(
            timeProvider: clock,
            liveStepMonitor: captureMonitor,
            backgroundCollector: delayingCollector,
          );

          final coordinator = deps.appLifecycleCoordinator;
          coordinator.bindToWidget(
            isMounted: () => true,
            showMainShell: () => true,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: true,
            maxPersistStaleness: const Duration(seconds: 1),
            minPauseForPhoneCatchUp: const Duration(seconds: 10),
            initialShowMainShell: true,
          );
          coordinator.onTodayCubitReady(todayCubit);

          await backfillDone.future.timeout(const Duration(seconds: 2));
          await coordinator.foregroundBackfill;
          await pumpEventQueue();

          expect(
            postBackfillReconcileSeen,
            isTrue,
            reason: 'reconcileAfterBackfillCompletes must run after backfill',
          );
          expect(
            todayCubit.state.steps,
            1500,
            reason:
                'post-backfill reconcile + syncSteps must apply DB steps after backfill',
          );

          await todayCubit.close();
          await captureMonitor.dispose();
        },
      );

      test(
        'onTodayCubitReady with enableLiveStepPipeline false waits backfill then refreshes Today',
        () async {
          final backfillDone = Completer<void>();
          final counting = _CountingStepAggregation(clock, stubbedSteps: 1200);
          final todayCubit = TodayCubit(
            stepAggregation: counting,
            userSettings: _ColdStartUserSettings(),
            userHealthMetrics: _ColdStartUserHealthMetrics(),
            clock: clock,
            activityPermissionGranted: () async => true,
          );

          final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
          final delayingCollector = _DelayingBackgroundCollector(
            sources: seedDeps.ingestionSources,
            normalizer: seedDeps.stepNormalizer,
            repository: seedDeps.stepIngestion,
            stepAggregation: seedDeps.stepAggregation,
            baselineRepository: IngestionBaselineRepository(
              seedDeps.databaseSession,
            ),
            collectDelay: const Duration(milliseconds: 100),
            onCollectStart: () {},
            onCollectEnd: () {
              expect(
                counting.getTodayStepsCallCount,
                0,
                reason: 'TodayCubit.refresh must wait for foregroundBackfill',
              );
              expect(todayCubit.state.lastDisplayedStepsLoaded, isFalse);
              if (!backfillDone.isCompleted) {
                backfillDone.complete();
              }
            },
          );
          final deps = buildCoordinatorUnitTestDeps(
            timeProvider: clock,
            backgroundCollector: delayingCollector,
          );
          final monitor = deps.liveStepMonitor;

          final coordinator = deps.appLifecycleCoordinator;
          coordinator.bindToWidget(
            isMounted: () => true,
            showMainShell: () => true,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
            maxPersistStaleness: const Duration(seconds: 1),
            minPauseForPhoneCatchUp: const Duration(seconds: 10),
            initialShowMainShell: true,
          );

          coordinator.onTodayCubitReady(todayCubit);
          expect(monitor.isRunning, isFalse);

          await backfillDone.future.timeout(const Duration(seconds: 2));
          await pumpEventQueue();

          expect(monitor.isRunning, isFalse);
          expect(counting.getTodayStepsCallCount, greaterThanOrEqualTo(1));
          expect(todayCubit.state.lastDisplayedStepsLoaded, isTrue);
          expect(todayCubit.state.status, isNot(TodayStatus.loading));
          expect(todayCubit.state.steps, 1200);

          await todayCubit.close();
        },
      );
    });

    test(
      'cold-start backfill passes Duration.zero to collectOnce (AUD-05)',
      () async {
        final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
        final capturingCollector = _SourceTimeoutCapturingBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
        );
        final deps = buildCoordinatorUnitTestDeps(
          timeProvider: clock,
          backgroundCollector: capturingCollector,
        );

        deps.appLifecycleCoordinator.bindToWidget(
          isMounted: () => true,
          showMainShell: () => true,
          enablePeriodicPersist: false,
          enableLiveStepPipeline: true,
          maxPersistStaleness: const Duration(seconds: 1),
          minPauseForPhoneCatchUp: const Duration(seconds: 10),
          initialShowMainShell: true,
        );
        await deps.appLifecycleCoordinator.foregroundBackfill;

        expect(capturingCollector.capturedTimeouts, isNotEmpty);
        expect(
          capturingCollector.capturedTimeouts.first,
          Duration.zero,
          reason:
              'cold-start backfill must skip empty phone drain via Duration.zero',
        );
      },
    );

    test(
      'post-pipeline persist cycle uses null (default 2 s) sourceTimeout (AC #2)',
      () async {
        final seedDeps = buildCoordinatorUnitTestDeps(timeProvider: clock);
        final capturingCollector = _SourceTimeoutCapturingBackgroundCollector(
          sources: seedDeps.ingestionSources,
          normalizer: seedDeps.stepNormalizer,
          repository: seedDeps.stepIngestion,
          stepAggregation: seedDeps.stepAggregation,
          baselineRepository: IngestionBaselineRepository(
            seedDeps.databaseSession,
          ),
        );
        final deps = buildCoordinatorUnitTestDeps(
          timeProvider: clock,
          backgroundCollector: capturingCollector,
        );
        final todayCubit = TodayCubit(
          stepAggregation: _ColdStartStepAggregation(clock),
          userSettings: _ColdStartUserSettings(),
          userHealthMetrics: _ColdStartUserHealthMetrics(),
          clock: clock,
          activityPermissionGranted: () async => true,
        );

        final coordinator = deps.appLifecycleCoordinator;
        coordinator.bindToWidget(
          isMounted: () => true,
          showMainShell: () => true,
          enablePeriodicPersist: false,
          enableLiveStepPipeline: true,
          maxPersistStaleness: const Duration(seconds: 1),
          minPauseForPhoneCatchUp: const Duration(seconds: 10),
          initialShowMainShell: true,
        );
        coordinator.onTodayCubitReady(todayCubit);
        await coordinator.foregroundBackfill;
        await pumpEventQueue();
        await pumpEventQueue();

        capturingCollector.capturedTimeouts.clear();

        await coordinator.enqueuePersistCycleForTest(
          enableGoalNotification: false,
        );

        expect(capturingCollector.capturedTimeouts, isNotEmpty);
        expect(
          capturingCollector.capturedTimeouts.last,
          isNull,
          reason:
              'post-pipeline persist must not override sourceTimeout (keeps 2 s default)',
        );

        await todayCubit.close();
      },
    );
  });
}
