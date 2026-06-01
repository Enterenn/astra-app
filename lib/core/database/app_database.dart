import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// Opens (or creates) the ASTRA SQLite database with WAL and foreign keys enabled.
///
/// Pass [databasePath] for tests (e.g. [inMemoryDatabasePath] via FFI factory).
Future<Database> openAstraDatabase({String? databasePath}) async {
  final path = databasePath ?? join(await getDatabasesPath(), 'astra_app.db');
  final db = await openDatabase(
    path,
    version: kDbVersion,
    onCreate: (db, version) async {
      await runMigrations(db, version);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await runMigrations(db, newVersion, fromVersion: oldVersion);
    },
  );
  if (path != inMemoryDatabasePath) {
    await db.execute('PRAGMA journal_mode=WAL;');
  }
  await db.execute('PRAGMA foreign_keys = ON;');
  return db;
}
