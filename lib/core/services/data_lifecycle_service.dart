import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../lifecycle/sample_compaction_runner.dart';
import '../time/time_provider.dart';
import '../database/isolate_database_factory.dart';

/// Weekly interval between database optimize/VACUUM runs (FR12).
const kDatabaseMaintenanceInterval = Duration(days: 7);

class LifecycleRunResult {
  const LifecycleRunResult({
    required this.skipped,
    this.compaction,
  });

  final bool skipped;
  final CompactionResult? compaction;
}

typedef DatabaseOptimizeRunner = Future<void> Function(
  Database db,
  String databasePath,
);

/// FR11 downsampling and FR12 `PRAGMA optimize` / `VACUUM` maintenance.
class DataLifecycleService {
  DataLifecycleService({
    required Database db,
    required String databasePath,
    required StepRepository repository,
    required UserPreferencesRepository userPreferences,
    required TimeProvider clock,
    DatabaseOptimizeRunner? optimizeAndVacuum,
  }) : _db = db,
       _databasePath = databasePath,
       _repository = repository,
       _userPreferences = userPreferences,
       _clock = clock,
       _optimizeAndVacuum = optimizeAndVacuum ?? runPragmaOptimizeAndVacuum;

  final Database _db;
  final String _databasePath;
  final StepRepository _repository;
  final UserPreferencesRepository _userPreferences;
  final TimeProvider _clock;
  final DatabaseOptimizeRunner _optimizeAndVacuum;

  /// True when no prior optimization timestamp exists or the weekly interval elapsed.
  Future<bool> isMaintenanceDue() async {
    final lastOptimized = await _userPreferences.getLastDatabaseOptimizedAt();
    if (lastOptimized == null) {
      return true;
    }

    final now = _clock.snapshot().nowUtc;
    return !now.isBefore(lastOptimized.add(kDatabaseMaintenanceInterval));
  }

  /// Runs downsampling and database maintenance when due, unless [force] is true.
  Future<LifecycleRunResult> runMaintenance({bool force = false}) async {
    if (!force && !await isMaintenanceDue()) {
      return const LifecycleRunResult(skipped: true);
    }

    final compaction = await _repository.downsampleStepSamples();
    await _optimizeAndVacuum(_db, _databasePath);
    await _userPreferences.setLastDatabaseOptimizedAt(_clock.snapshot().nowUtc);

    return LifecycleRunResult(skipped: false, compaction: compaction);
  }
}

/// Runs `PRAGMA optimize` then `VACUUM` off the UI isolate when using a file DB.
Future<void> runPragmaOptimizeAndVacuum(
  Database db,
  String databasePath,
) async {
  if (databasePath == inMemoryDatabasePath) {
    await db.rawQuery('PRAGMA optimize');
    await db.execute('VACUUM');
    return;
  }

  await compute(_vacuumDatabaseAtPath, databasePath);
}

Future<void> _vacuumDatabaseAtPath(String databasePath) async {
  final isolateDb = await openIsolateAstraDatabase(databasePath: databasePath);
  try {
    await isolateDb.rawQuery('PRAGMA optimize');
    await isolateDb.execute('VACUUM');
  } finally {
    await isolateDb.close();
  }
}
