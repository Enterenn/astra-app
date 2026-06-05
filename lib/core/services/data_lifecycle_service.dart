import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../lifecycle/sample_compaction_runner.dart';
import '../time/time_provider.dart';
import '../time/system_time_provider.dart';
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

/// Runs downsampling, optimize/VACUUM, and preference update on an open connection.
///
/// Used by WorkManager (exclusive isolate DB) and in-memory tests. Callers that
/// hold the app's long-lived UI [Database] for a file path must use
/// [DataLifecycleService.runMaintenance] (isolate offload) instead.
@visibleForTesting
Future<LifecycleRunResult> runMaintenanceOnConnection({
  required Database db,
  required String databasePath,
  required StepRepository repository,
  required UserPreferencesRepository userPreferences,
  required TimeProvider clock,
  required bool force,
  DatabaseOptimizeRunner optimizeAndVacuum =
      runPragmaOptimizeAndVacuumOnWorkerIsolate,
}) async {
  if (!force && !await _isMaintenanceDue(userPreferences, clock)) {
    return const LifecycleRunResult(skipped: true);
  }

  final compaction = await repository.downsampleStepSamples();
  await optimizeAndVacuum(db, databasePath);
  await userPreferences.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

  return LifecycleRunResult(skipped: false, compaction: compaction);
}

Future<bool> _isMaintenanceDue(
  UserPreferencesRepository userPreferences,
  TimeProvider clock,
) async {
  final lastOptimized = await userPreferences.getLastDatabaseOptimizedAt();
  if (lastOptimized == null) {
    return true;
  }

  final now = clock.snapshot().nowUtc;
  return !now.isBefore(lastOptimized.add(kDatabaseMaintenanceInterval));
}

class _FileMaintenanceRequest {
  const _FileMaintenanceRequest({
    required this.databasePath,
    required this.force,
  });

  final String databasePath;
  final bool force;
}

Future<LifecycleRunResult> _runFileMaintenanceIsolate(
  _FileMaintenanceRequest request,
) async {
  final db = await openIsolateAstraDatabase(databasePath: request.databasePath);
  try {
    const clock = SystemTimeProvider();
    return runMaintenanceOnConnection(
      db: db,
      databasePath: request.databasePath,
      repository: StepRepository(db: db, clock: clock),
      userPreferences: UserPreferencesRepository(db),
      clock: clock,
      force: request.force,
    );
  } finally {
    await db.close();
  }
}

/// FR11 downsampling and FR12 `PRAGMA optimize` / `VACUUM` maintenance.
///
/// Phase 0 scheduling: Android weekly WorkManager; iOS opportunistic on
/// [AppLifecycleState.resumed] when due. Reliable iOS background VACUUM is not
/// required for acceptance — foreground/resume is sufficient.
///
/// File-backed databases run the full pipeline in a [compute] isolate with a
/// short-lived connection so VACUUM does not race the UI connection. Pass
/// [maintenanceOnCurrentConnection] when the caller already owns an exclusive
/// connection (WorkManager background isolate).
class DataLifecycleService {
  DataLifecycleService({
    required Database db,
    required String databasePath,
    required StepRepository repository,
    required UserPreferencesRepository userPreferences,
    required TimeProvider clock,
    DatabaseOptimizeRunner? optimizeAndVacuum,
    bool maintenanceOnCurrentConnection = false,
  }) : _db = db,
       _databasePath = databasePath,
       _repository = repository,
       _userPreferences = userPreferences,
       _clock = clock,
       _optimizeAndVacuum =
           optimizeAndVacuum ?? runPragmaOptimizeAndVacuumOnWorkerIsolate,
       _maintenanceOnCurrentConnection = maintenanceOnCurrentConnection;

  final Database _db;
  final String _databasePath;
  final StepRepository _repository;
  final UserPreferencesRepository _userPreferences;
  final TimeProvider _clock;
  final DatabaseOptimizeRunner _optimizeAndVacuum;
  final bool _maintenanceOnCurrentConnection;

  Future<LifecycleRunResult>? _maintenanceInFlight;

  /// True when no prior optimization timestamp exists or the weekly interval elapsed.
  Future<bool> isMaintenanceDue() async {
    return _isMaintenanceDue(_userPreferences, _clock);
  }

  /// Runs downsampling and database maintenance when due, unless [force] is true.
  ///
  /// Concurrent callers share one in-flight run (second caller awaits the first).
  Future<LifecycleRunResult> runMaintenance({bool force = false}) async {
    if (_maintenanceInFlight != null) {
      return _maintenanceInFlight!;
    }

    final run = _runMaintenanceImpl(force: force);
    _maintenanceInFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_maintenanceInFlight, run)) {
        _maintenanceInFlight = null;
      }
    }
  }

  Future<LifecycleRunResult> _runMaintenanceImpl({required bool force}) async {
    final useIsolateOffload = _databasePath != inMemoryDatabasePath &&
        !_maintenanceOnCurrentConnection &&
        !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS);

    if (useIsolateOffload) {
      return _runFileMaintenanceInBackgroundIsolate(
        _FileMaintenanceRequest(
          databasePath: _databasePath,
          force: force,
        ),
      );
    }

    return runMaintenanceOnConnection(
      db: _db,
      databasePath: _databasePath,
      repository: _repository,
      userPreferences: _userPreferences,
      clock: _clock,
      force: force,
      optimizeAndVacuum: _optimizeAndVacuum,
    );
  }
}

/// Runs file maintenance in a short-lived isolate with plugin messenger init.
///
/// [compute] does not register platform channels; sqflite needs
/// [BackgroundIsolateBinaryMessenger.ensureInitialized] on mobile.
Future<LifecycleRunResult> _runFileMaintenanceInBackgroundIsolate(
  _FileMaintenanceRequest request,
) async {
  final token = RootIsolateToken.instance;
  if (token == null) {
    return _runFileMaintenanceIsolate(request);
  }

  return Isolate.run(() async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    return _runFileMaintenanceIsolate(request);
  });
}

/// Runs `PRAGMA optimize` then `VACUUM` on the caller's open [db] connection.
///
/// Use when the caller owns an exclusive connection (WorkManager isolate, tests).
/// UI-triggered file maintenance uses [compute] via [DataLifecycleService] instead
/// of opening a second connection while the app DB stays open.
Future<void> runPragmaOptimizeAndVacuumOnWorkerIsolate(
  Database db,
  String databasePath,
) async {
  await db.rawQuery('PRAGMA optimize');
  await db.execute('VACUUM');
}

/// Runs `PRAGMA optimize` then `VACUUM` on the given connection.
Future<void> runPragmaOptimizeAndVacuum(
  Database db,
  String databasePath,
) async {
  await runPragmaOptimizeAndVacuumOnWorkerIsolate(db, databasePath);
}
