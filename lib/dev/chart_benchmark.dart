import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/time/time_provider.dart';
import '../data/models/chart_day_aggregate.dart';
import '../data/repositories/step_repository.dart';
import '../data/repositories/user_preferences_repository.dart';
import '../presentation/cubits/history_cubit.dart';
import '../presentation/cubits/history_state.dart';
import 'data_inject_service.dart';
import 'lifecycle_simulator.dart';

const kChartBenchmarkDefaultIterations = 50;
const kChartBenchmarkPassThresholdMs = 100;

const kDatasetLabelRaw25920 = 'raw-25920';
const kDatasetLabelCompacted10080 = 'compacted-10080';

/// Per-iteration phase timings captured during a benchmark run.
class ChartBenchmarkIteration {
  const ChartBenchmarkIteration({
    required this.queryMs,
    required this.toggleMs,
  });

  final double queryMs;
  final double toggleMs;

  double get totalMs => queryMs + toggleMs;
}

/// Aggregated KPI-01 benchmark output with percentile summaries.
class ChartBenchmarkResult {
  const ChartBenchmarkResult({
    required this.iterations,
    required this.queryP50Ms,
    required this.queryP95Ms,
    required this.toggleP50Ms,
    required this.toggleP95Ms,
    required this.totalP50Ms,
    required this.totalP95Ms,
    required this.datasetLabel,
    required this.rowCount,
    required this.passed,
  });

  final int iterations;
  final double queryP50Ms;
  final double queryP95Ms;
  final double toggleP50Ms;
  final double toggleP95Ms;
  final double totalP50Ms;
  final double totalP95Ms;
  final String datasetLabel;
  final int rowCount;
  final bool passed;
}

/// Optional widget pump hook for measuring chart rebuild cost in tests.
typedef ChartBenchmarkWidgetPump = Future<void> Function({
  required List<ChartDayAggregate> points7d,
  required List<ChartDayAggregate> points30d,
  required int dailyGoal,
});

/// Runs KPI-01 chart query + toggle/render benchmark in debug builds only.
Future<ChartBenchmarkResult> runChartBenchmark({
  required StepRepository repository,
  required TimeProvider clock,
  Database? db,
  UserPreferencesRepository? userPreferences,
  int iterations = kChartBenchmarkDefaultIterations,
  bool runLifecycleCompaction = false,
  bool skipDatasetSetup = false,
  ChartBenchmarkWidgetPump? pumpChart,
  bool assertPassGate = false,
}) async {
  if (!kDebugMode) {
    throw StateError('Chart benchmark is only available in debug builds');
  }
  if (iterations <= 0) {
    throw ArgumentError.value(iterations, 'iterations', 'must be positive');
  }
  if (runLifecycleCompaction && db == null) {
    throw ArgumentError(
      'db is required when runLifecycleCompaction is true',
    );
  }

  if (!skipDatasetSetup) {
    await DataInjectService(repository: repository).inject90Days(clock: clock);

    if (runLifecycleCompaction) {
      await LifecycleSimulator(
        db: db!,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();
    }
  } else if (runLifecycleCompaction) {
    throw ArgumentError(
      'runLifecycleCompaction requires skipDatasetSetup to be false',
    );
  }

  final rowCount = await repository.countStepSamples();
  final datasetLabel = _datasetLabelForRowCount(rowCount);

  final prefs =
      userPreferences ?? UserPreferencesRepository(repository.db);
  final cubit = HistoryCubit(
    stepRepository: repository,
    userPreferences: prefs,
  );

  try {
    await repository.getChartDailyAggregates(days: 30);
    await cubit.refresh();
    if (cubit.state.status != HistoryStatus.ready) {
      throw StateError(
        'Warm-up failed: expected ready state after inject, got '
        '${cubit.state.status}',
      );
    }

    final querySamples = <double>[];
    final toggleSamples = <double>[];
    final totalSamples = <double>[];

    for (var i = 0; i < iterations; i++) {
      final queryStopwatch = Stopwatch()..start();
      await repository.getChartDailyAggregates(days: 30);
      queryStopwatch.stop();
      final queryMs = queryStopwatch.elapsedMicroseconds / 1000.0;

      final toggleStopwatch = Stopwatch()..start();
      await benchmarkToggleRender(
        cubit: cubit,
        pumpChart: pumpChart,
      );
      toggleStopwatch.stop();
      final toggleMs = toggleStopwatch.elapsedMicroseconds / 1000.0;

      querySamples.add(queryMs);
      toggleSamples.add(toggleMs);
      totalSamples.add(queryMs + toggleMs);
    }

    final queryP50 = _percentile(querySamples, 0.50);
    final queryP95 = _percentile(querySamples, 0.95);
    final toggleP50 = _percentile(toggleSamples, 0.50);
    final toggleP95 = _percentile(toggleSamples, 0.95);
    final totalP50 = _percentile(totalSamples, 0.50);
    final totalP95 = _percentile(totalSamples, 0.95);
    final passed = totalP95 < kChartBenchmarkPassThresholdMs;

    final result = ChartBenchmarkResult(
      iterations: iterations,
      queryP50Ms: queryP50,
      queryP95Ms: queryP95,
      toggleP50Ms: toggleP50,
      toggleP95Ms: toggleP95,
      totalP50Ms: totalP50,
      totalP95Ms: totalP95,
      datasetLabel: datasetLabel,
      rowCount: rowCount,
      passed: passed,
    );

    _logBenchmarkResult(result);

    if (assertPassGate && !passed) {
      throw StateError(
        'KPI-01 failed: total p95 ${totalP95.toStringAsFixed(2)}ms '
        '>= $kChartBenchmarkPassThresholdMs ms',
      );
    }

    return result;
  } finally {
    await cubit.close();
  }
}

/// Toggles 7d ↔ 30d on a warmed [HistoryCubit] and optionally pumps chart UI.
Future<void> benchmarkToggleRender({
  required HistoryCubit cubit,
  ChartBenchmarkWidgetPump? pumpChart,
}) async {
  if (cubit.state.status != HistoryStatus.ready) {
    throw StateError(
      'benchmarkToggleRender requires ready cubit state, got '
      '${cubit.state.status}',
    );
  }

  final dailyGoal = cubit.state.dailyGoal;

  cubit.selectPeriod(HistoryPeriod.days7);
  final points7d = List<ChartDayAggregate>.from(cubit.state.chartPoints);

  cubit.selectPeriod(HistoryPeriod.days30);
  final points30d = List<ChartDayAggregate>.from(cubit.state.chartPoints);

  if (pumpChart != null) {
    await pumpChart(
      points7d: points7d,
      points30d: points30d,
      dailyGoal: dailyGoal,
    );
  }
}

double _percentile(List<double> samples, double p) {
  if (samples.isEmpty) {
    return 0;
  }

  final sorted = List<double>.from(samples)..sort();
  final index = (p * sorted.length).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

String _datasetLabelForRowCount(int rowCount) {
  if (rowCount == 10080) {
    return kDatasetLabelCompacted10080;
  }
  if (rowCount == kDevInjectExpectedRowCount) {
    return kDatasetLabelRaw25920;
  }
  return 'custom-$rowCount';
}

void _logBenchmarkResult(ChartBenchmarkResult result) {
  debugPrint(
    '[KPI-01] dataset=${result.datasetLabel} rows=${result.rowCount} '
    'iterations=${result.iterations} '
    'query_p50=${result.queryP50Ms.toStringAsFixed(2)}ms '
    'query_p95=${result.queryP95Ms.toStringAsFixed(2)}ms '
    'toggle_p50=${result.toggleP50Ms.toStringAsFixed(2)}ms '
    'toggle_p95=${result.toggleP95Ms.toStringAsFixed(2)}ms '
    'total_p50=${result.totalP50Ms.toStringAsFixed(2)}ms '
    'total_p95=${result.totalP95Ms.toStringAsFixed(2)}ms '
    'pass=${result.passed}',
  );
}
