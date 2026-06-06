import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// UI-isolate SQLite handle that survives [database_closed] from other isolates.
///
/// WorkManager and file-picker flows can open/close their own connections on the
/// same path; sqflite on Android may invalidate the app connection. [withRetry]
/// reopens once and retries the action.
class AstraDatabaseSession {
  AstraDatabaseSession({
    required this.databasePath,
    Database? initial,
  }) : _db = initial;

  final String databasePath;
  Database? _db;
  Future<void>? _reopenInFlight;

  Database get database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('Database is not open');
    }
    return db;
  }

  static bool isDatabaseClosedError(Object error) {
    return error is DatabaseException &&
        error.toString().contains('database_closed');
  }

  Future<void> ensureOpen() async {
    final db = _db;
    if (db != null && db.isOpen) {
      return;
    }
    await reopen();
  }

  Future<void> reopen() async {
    if (_reopenInFlight != null) {
      return _reopenInFlight!;
    }

    final reopen = _reopenImpl();
    _reopenInFlight = reopen;
    try {
      await reopen;
    } finally {
      if (identical(_reopenInFlight, reopen)) {
        _reopenInFlight = null;
      }
    }
  }

  Future<void> _reopenImpl() async {
    final previous = _db;
    _db = null;
    if (previous != null && previous.isOpen) {
      await previous.close();
    }
    _db = await openAstraDatabase(databasePath: databasePath);
  }

  Future<T> withRetry<T>(Future<T> Function(Database db) action) async {
    await ensureOpen();
    try {
      return await action(_db!);
    } catch (error) {
      if (!isDatabaseClosedError(error)) {
        rethrow;
      }
      await reopen();
      return await action(_db!);
    }
  }
}
