import 'package:sqflite/sqflite.dart';

import '../constants/preference_keys.dart';
import '../database/astra_database_session.dart';
import '../time/time_provider.dart';

/// TTL for [IngestionCollectionLock.forMaintenance] — downsample + VACUUM can exceed collection TTL.
const kDatabaseMaintenanceLockTtl = Duration(minutes: 10);

/// Cross-isolate ingestion mutex backed by SQLite [user_preferences].
///
/// WorkManager, FGS, and UI collectors share one DB file; instance-level
/// [_collectInFlight] on [BackgroundCollector] is not enough.
class IngestionCollectionLock {
  IngestionCollectionLock(
    this._session, {
    String? lockKey,
    Duration? ttl,
    TimeProvider? clock,
  })  : _lockKey = lockKey ?? kIngestionCollectLockKey,
        ttl = ttl ?? const Duration(seconds: 35),
        _clock = clock;

  factory IngestionCollectionLock.forMaintenance(
    AstraDatabaseSession session, {
    TimeProvider? clock,
  }) =>
      IngestionCollectionLock(
        session,
        lockKey: kDatabaseMaintenanceLockKey,
        ttl: kDatabaseMaintenanceLockTtl,
        clock: clock,
      );

  final AstraDatabaseSession _session;
  final String _lockKey;
  final Duration ttl;
  final TimeProvider? _clock;

  /// Returns true when [lockKey] has a non-expired holder row.
  static Future<bool> isHeld(
    AstraDatabaseSession session,
    String lockKey, {
    TimeProvider? clock,
  }) async {
    final now =
        (clock?.nowUtc() ?? DateTime.now().toUtc()).millisecondsSinceEpoch;

    return session.withRetry(
      (db) async {
        final rows = await db.query(
          'user_preferences',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [lockKey],
          limit: 1,
        );
        if (rows.isEmpty) return false;
        final heldUntil =
            int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
        return heldUntil > now;
      },
    );
  }

  String? get _opposingLockKey {
    if (_lockKey == kIngestionCollectLockKey) {
      return kDatabaseMaintenanceLockKey;
    }
    if (_lockKey == kDatabaseMaintenanceLockKey) {
      return kIngestionCollectLockKey;
    }
    return null;
  }

  /// Returns false when another collector holds a non-expired lock.
  Future<bool> tryAcquire() async {
    final now =
        (_clock?.nowUtc() ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final expiry = now + ttl.inMilliseconds;

    return _session.withRetry(
      (db) => db.transaction<bool>((txn) async {
        for (final key in [_lockKey, ?_opposingLockKey]) {
          final rows = await txn.query(
            'user_preferences',
            columns: ['value'],
            where: 'key = ?',
            whereArgs: [key],
            limit: 1,
          );
          if (rows.isEmpty) continue;
          final heldUntil =
              int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
          if (heldUntil > now) {
            return false;
          }
        }

        await txn.insert(
          'user_preferences',
          {
            'key': _lockKey,
            'value': expiry.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }),
    );
  }

  Future<void> release() async {
    await _session.withRetry(
      (db) => db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [_lockKey],
      ),
    );
  }
}
