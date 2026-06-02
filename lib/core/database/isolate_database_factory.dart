import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Opens a fresh ASTRA database connection for the current isolate.
///
/// Use this from both the UI isolate and WorkManager background isolates. The
/// returned [Database] is never cached here, so each call creates an independent
/// connection while preserving the shared PRAGMA and migration behavior from
/// [openAstraDatabase].
Future<Database> openIsolateAstraDatabase({String? databasePath}) {
  return openAstraDatabase(databasePath: databasePath);
}
