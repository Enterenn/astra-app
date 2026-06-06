import 'package:sqflite/sqflite.dart';

import '../../core/database/astra_database_session.dart';

/// Persists the last seen cumulative step counter per ingestion source.
///
/// Used so a single pedometer reading in a short WorkManager window can still
/// produce a delta against the previous run's baseline.
class IngestionBaselineRepository {
  IngestionBaselineRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
  }) : _session = sessionOrDatabase is AstraDatabaseSession
           ? sessionOrDatabase
           : AstraDatabaseSession(
               databasePath: databasePath,
               initial: sessionOrDatabase as Database,
             );

  final AstraDatabaseSession _session;

  static const baselineKeyPrefix = 'ingestion_baseline/';

  static String preferenceKey({
    required String provider,
    required String deviceId,
  }) => '$baselineKeyPrefix$provider/$deviceId';

  /// Removes all ingestion baseline keys inside an existing [txn] (purge path).
  static Future<void> clearAllBaselines(Transaction txn) async {
    await txn.delete(
      'user_preferences',
      where: 'key LIKE ?',
      whereArgs: ['$baselineKeyPrefix%'],
    );
  }

  Future<int?> getBaseline({
    required String provider,
    required String deviceId,
  }) {
    return _session.withRetry((db) async {
      final rows = await db.query(
        'user_preferences',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [preferenceKey(provider: provider, deviceId: deviceId)],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return int.tryParse(rows.first['value'] as String? ?? '');
    });
  }

  Future<void> setBaseline({
    required String provider,
    required String deviceId,
    required int cumulative,
  }) {
    if (cumulative < 0) {
      throw ArgumentError.value(cumulative, 'cumulative', 'must be non-negative');
    }
    return _session.withRetry(
      (db) => db.insert(
        'user_preferences',
        {
          'key': preferenceKey(provider: provider, deviceId: deviceId),
          'value': cumulative.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }
}
