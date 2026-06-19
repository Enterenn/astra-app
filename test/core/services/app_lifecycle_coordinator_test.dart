import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/app_lifecycle_coordinator.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/coordinator_unit_test_deps.dart';
import '../../helpers/recording_health_fgs.dart';
import '../time/fake_time_provider.dart';

class _DelayingBackgroundCollector extends BackgroundCollector {
  _DelayingBackgroundCollector({
    required super.sources,
    required super.normalizer,
    required super.repository,
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
        repository: seedDeps.stepRepository,
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
          repository: seedDeps.stepRepository,
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
      final stepsBefore = await deps.stepRepository.getTodaySteps();

      await coordinator.runLocalDayBoundaryIfNeededForTest();

      final stepsAfter = await deps.stepRepository.getTodaySteps();
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
          repository: seedDeps.stepRepository,
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
  });
}
