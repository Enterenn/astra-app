import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/lifecycle/sample_compaction_runner.dart';
import '../core/time/time_provider.dart';
import '../data/models/normalized_step_bucket.dart';
import '../data/repositories/step_repository.dart';

class LifecycleSimResult {
  const LifecycleSimResult({
    required this.rowsBefore,
    required this.rowsAfter,
    required this.fiveMinRemaining,
    required this.hourlyCreated,
    required this.dailyCreated,
  });

  final int rowsBefore;
  final int rowsAfter;
  final int fiveMinRemaining;
  final int hourlyCreated;
  final int dailyCreated;
}

/// Dev-only FR11 downsampling preview for chart benchmark datasets.
class LifecycleSimulator {
  LifecycleSimulator({
    required this.db,
    required this.repository,
    required this.clock,
  });

  final Database db;
  final StepRepository repository;
  final TimeProvider clock;

  Future<LifecycleSimResult> simulateDownsampling() async {
    final rowsBefore = await repository.countStepSamples();
    final compactionResult = await repository.downsampleStepSamples();
    final countsByResolution = await repository.countStepSamplesByResolution();
    final rowsAfter = await repository.countStepSamples();

    return LifecycleSimResult(
      rowsBefore: rowsBefore,
      rowsAfter: rowsAfter,
      fiveMinRemaining: countsByResolution[kFiveMinuteResolution] ?? 0,
      hourlyCreated: compactionResult.hourlyCreated,
      dailyCreated: compactionResult.dailyCreated,
    );
  }
}

Future<LifecycleSimResult> runDevLifecycleSimulate({
  required Database db,
  required StepRepository repository,
  required TimeProvider clock,
}) async {
  if (!kDebugMode) {
    throw StateError('Dev lifecycle simulate is only available in debug builds');
  }

  return LifecycleSimulator(
    db: db,
    repository: repository,
    clock: clock,
  ).simulateDownsampling();
}
