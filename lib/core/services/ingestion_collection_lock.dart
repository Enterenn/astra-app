import 'package:sqflite/sqflite.dart';

import '../constants/preference_keys.dart';
import '../time/time_provider.dart';

/// Cross-isolate ingestion mutex backed by SQLite [user_preferences].
///
/// WorkManager, FGS, and UI collectors share one DB file; instance-level
/// [_collectInFlight] on [BackgroundCollector] is not enough.
class IngestionCollectionLock {
  IngestionCollectionLock(
    this._db, {
    this.ttl = const Duration(seconds: 35),
    TimeProvider? clock,
  }) : _clock = clock;

  final Database _db;
  final Duration ttl;
  final TimeProvider? _clock;

  /// Returns false when another collector holds a non-expired lock.
  Future<bool> tryAcquire() async {
    final now = (_clock?.nowUtc() ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final expiry = now + ttl.inMilliseconds;

    return _db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'user_preferences',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [kIngestionCollectLockKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final heldUntil =
            int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
        if (heldUntil > now) {
          return false;
        }
      }

      await txn.insert(
        'user_preferences',
        {
          'key': kIngestionCollectLockKey,
          'value': expiry.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    });
  }

  Future<void> release() async {
    await _db.delete(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [kIngestionCollectLockKey],
    );
  }
}
