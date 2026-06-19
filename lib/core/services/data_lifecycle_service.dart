import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/step/step_aggregation_repository.dart';
import '../../data/repositories/user_settings_repository.dart';
import '../lifecycle/sample_compaction_runner.dart';
import '../time/time_provider.dart';
import '../time/system_time_provider.dart';
import '../database/isolate_database_factory.dart';
import '../database/astra_database_session.dart';

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
  required StepAggregationRepository repository,
  required UserSettingsRepository userSettings,
  required TimeProvider clock,
  required bool force,
  DatabaseOptimizeRunner optimizeAndVacuum =
      runPragmaOptimizeAndVacuumOnWorkerIsolate,
}) async {
  if (!force && !await _isMaintenanceDue(userSettings, clock)) {
    return const LifecycleRunResult(skipped: true);
  }

  final compaction = await repository.downsampleStepSamples();
  await optimizeAndVacuum(db, databasePath);
  await userSettings.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);

  return LifecycleRunResult(skipped: false, compaction: compaction);
}

Future<bool> _isMaintenanceDue(
  UserSettingsRepository userSettings,
  TimeProvider clock,
) async {
  final lastOptimized = await userSettings.getLastDatabaseOptimizedAt();
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
      repository: StepAggregationRepository(db, clock: clock),
      userSettings: UserSettingsRepository(db),
      clock: clock,
      force: request.force,
    );
  } finally {
    await db.close();
  }
}

/// FR11 downsampling and FR12 `PRAGMA optimize` / `VACUUM` maintenance.
///
/// Phase 0 scheduling: Android weekly WorkManager; iOS via WorkManager /
/// My Data flows — not on app resume (resume must not VACUUM while UI DB is open).
///
/// File-backed databases run the full pipeline in a [compute] isolate with a
/// short-lived connection so VACUUM does not race the UI connection. Pass
/// [maintenanceOnCurrentConnection] when the caller already owns an exclusive
/// connection (WorkManager background isolate).
class DataLifecycleService {
  DataLifecycleService({
    required String databasePath,
    required StepAggregationRepository repository,
    required UserSettingsRepository userSettings,
    required TimeProvider clock,
    AstraDatabaseSession? session,
    Database? db,
    DatabaseOptimizeRunner? optimizeAndVacuum,
    bool maintenanceOnCurrentConnection = false,
  }) : _session =
           session ??
           AstraDatabaseSession(
             databasePath: databasePath,
             initial: db!,
           ),
       _databasePath = databasePath,
       _repository = repository,
       _userSettings = userSettings,
       _clock = clock,
       _optimizeAndVacuum =
           optimizeAndVacuum ?? runPragmaOptimizeAndVacuumOnWorkerIsolate,
       _maintenanceOnCurrentConnection = maintenanceOnCurrentConnection,
       assert(session != null || db != null);

  final AstraDatabaseSession _session;
  final String _databasePath;
  final StepAggregationRepository _repository;
  final UserSettingsRepository _userSettings;
  final TimeProvider _clock;
  final DatabaseOptimizeRunner _optimizeAndVacuum;
  final bool _maintenanceOnCurrentConnection;

  Future<LifecycleRunResult>? _maintenanceInFlight;

  /// True when no prior optimization timestamp exists or the weekly interval elapsed.
  Future<bool> isMaintenanceDue() async {
    return _isMaintenanceDue(_userSettings, _clock);
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

    return _session.withRetry(
      (db) => runMaintenanceOnConnection(
        db: db,
        databasePath: _databasePath,
        repository: _repository,
        userSettings: _userSettings,
        clock: _clock,
        force: force,
        optimizeAndVacuum: _optimizeAndVacuum,
      ),
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
