import 'package:sqflite/sqflite.dart';

import '../../../core/database/astra_database_session.dart';

/// Shared SQLite session wrapper for step ingestion, aggregation, and CSV I/O.
class StepRepositorySession {
  StepRepositorySession(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
  }) : _session = sessionOrDatabase is AstraDatabaseSession
           ? sessionOrDatabase
           : AstraDatabaseSession(
               databasePath: databasePath,
               initial: sessionOrDatabase as Database,
             );

  final AstraDatabaseSession _session;

  AstraDatabaseSession get session => _session;

  Database get db => _session.database;

  Future<T> run<T>(Future<T> Function(Database db) action) =>
      _session.withRetry(action);
}
