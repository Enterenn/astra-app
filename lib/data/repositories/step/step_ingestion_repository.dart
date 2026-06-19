import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/preference_keys.dart';
import '../../../core/ids/sample_id_generator.dart';
import '../../contracts/step_ingestion_repository_contract.dart';
import '../../models/normalized_step_bucket.dart';
import '../../models/timeseries_sample_model.dart';
import '../ingestion_baseline_repository.dart';
import '_step_repository_session.dart';

class StepIngestionRepository implements StepIngestionRepositoryContract {
  StepIngestionRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
  }) : _session = StepRepositorySession(
         sessionOrDatabase,
         databasePath: databasePath,
       );

  final StepRepositorySession _session;

  Database get db => _session.db;

  /// Persists an ingestion bucket from the background collection pipeline only.
  ///
  /// On bucket identity conflict, [bucket.value] is **added** to the stored total
  /// (per-collect increment), not replaced. Production callers must be limited to
  /// `BackgroundCollector` once Story 2.4 wires that component. Tests may call
  /// this method directly.
  Future<void> upsertIngestionBucket(NormalizedStepBucket bucket) async {
    final model = TimeseriesSampleModel.fromNormalizedBucket(
      bucket: bucket,
      id: SampleIdGenerator.deterministicFromIngestionBucket(
        startTimeUtc: bucket.startTimeUtc,
        provider: bucket.provider,
        deviceId: bucket.deviceId,
      ),
    );
    final row = model.toMap();

    await _session.run(
      (db) => db.rawInsert(
        '''
      INSERT INTO timeseries_samples (
        id,
        start_time,
        end_time,
        type,
        value,
        unit,
        resolution,
        provider,
        device_id,
        zone_offset
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
      DO UPDATE SET value = timeseries_samples.value + excluded.value
      ''',
        [
          row['id'],
          row['start_time'],
          row['end_time'],
          row['type'],
          row['value'],
          row['unit'],
          row['resolution'],
          row['provider'],
          row['device_id'],
          row['zone_offset'],
        ],
      ),
    );
  }

  /// Inserts pre-built sample rows in a single transaction.
  ///
  /// **Dev/test only** — only [DataInjectService] and unit tests may call this
  /// method. Production ingestion must use [upsertIngestionBucket].
  ///
  /// When [replaceExistingSteps] is true, existing `type='steps'` rows are
  /// deleted in the same transaction before inserts (atomic clear-and-replace).
  Future<void> insertDevSamplesBatch(
    List<TimeseriesSampleModel> samples, {
    bool replaceExistingSteps = false,
  }) async {
    assert(() {
      if (!kDebugMode) {
        throw StateError(
          'insertDevSamplesBatch is only available in debug builds',
        );
      }
      return true;
    }());

    await _session.run(
      (db) => db.transaction((txn) async {
        if (replaceExistingSteps) {
          await txn.delete(
            'timeseries_samples',
            where: 'type = ?',
            whereArgs: [kStepSampleType],
          );
        }

        for (final sample in samples) {
          final row = sample.toMap();
          await txn.insert('timeseries_samples', row);
        }
      }),
    );
  }

  /// Wipes all health data and derived collection state in a single transaction (FR-20, D-24).
  ///
  /// Preserves setup preferences: daily goal, theme, onboarding, and future non-health keys.
  /// VACUUM / file shrink is the caller's responsibility via [DataLifecycleService].
  @override
  Future<void> purge({
    @visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  }) async {
    await _session.run(
      (db) => db.transaction((txn) async {
        await txn.delete('timeseries_samples');
        if (testHookAfterDeleteSamples != null) {
          await testHookAfterDeleteSamples(txn);
        }
        await IngestionBaselineRepository.clearAllBaselines(txn);
        for (final key in [
          kCelebrationShownDateKey,
          kGoalNotificationShownDateKey,
          kIngestionCollectLockKey,
          kLastDatabaseOptimizedAtKey,
        ]) {
          await txn.delete(
            'user_preferences',
            where: 'key = ?',
            whereArgs: [key],
          );
        }
      }),
    );
  }
}
