import 'package:sqflite/sqflite.dart';

import '../../core/database/astra_database_session.dart';

/// Shared key-value primitives for repositories writing to `user_preferences`.
class UserPreferencesKvStore {
  UserPreferencesKvStore(this._session);

  final AstraDatabaseSession _session;

  AstraDatabaseSession get session => _session;

  bool get isDatabaseOpen => _session.database.isOpen;

  Future<String?> readValue(String key) {
    return _session.withRetry((db) async {
      final rows = await db.query(
        'user_preferences',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return rows.first['value'] as String?;
    });
  }

  Future<void> writeValue(String key, String value) {
    return _session.withRetry(
      (db) => db.insert(
        'user_preferences',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }

  Future<void> deleteValue(String key) {
    return _session.withRetry(
      (db) => db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [key],
      ),
    );
  }
}
