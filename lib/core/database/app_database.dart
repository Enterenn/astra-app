import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../time/time_provider.dart';
import 'migrations.dart';

/// SQLite busy wait (ms) before returning `SQLITE_BUSY` on lock contention.
const kDatabaseBusyTimeoutMs = 5000;

/// Opens (or creates) the ASTRA SQLite database with WAL and foreign keys enabled.
///
/// Pass [databasePath] for tests (e.g. [inMemoryDatabasePath] via FFI factory).
Future<Database> openAstraDatabase({
  String? databasePath,
  TimeProvider? clock,
}) async {
  final path = databasePath ?? join(await getDatabasesPath(), 'astra_app.db');
  final enableWal = path != inMemoryDatabasePath;

  return openDatabase(
    path,
    version: kDbVersion,
    onConfigure: (db) async {
      // Android requires rawQuery for PRAGMA (execute() throws DatabaseException).
      if (enableWal) {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      }
      await db.rawQuery('PRAGMA foreign_keys = ON');
      await db.rawQuery('PRAGMA busy_timeout = $kDatabaseBusyTimeoutMs');
    },
    onCreate: (db, version) async {
      await runMigrations(db, version, clock: clock);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await runMigrations(db, newVersion, fromVersion: oldVersion, clock: clock);
    },
  );
}
