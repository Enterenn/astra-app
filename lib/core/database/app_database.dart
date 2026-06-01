import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// Opens (or creates) the ASTRA SQLite database with WAL and foreign keys enabled.
///
/// Pass [databasePath] for tests (e.g. [inMemoryDatabasePath] via FFI factory).
Future<Database> openAstraDatabase({String? databasePath}) async {
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
    },
    onCreate: (db, version) async {
      await runMigrations(db, version);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await runMigrations(db, newVersion, fromVersion: oldVersion);
    },
  );
}
