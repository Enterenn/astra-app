import 'package:sqflite/sqflite.dart';

import '../constants/preference_keys.dart';

const kDbVersion = 1;

/// Runs migrations from [fromVersion] (exclusive) up to [targetVersion].
Future<void> runMigrations(
  Database db,
  int targetVersion, {
  int fromVersion = 0,
}) async {
  for (var version = fromVersion + 1; version <= targetVersion; version++) {
    switch (version) {
      case 1:
        await onCreateV1(db);
      default:
        break;
    }
  }
}

/// Migration v1: `user_preferences` only (no timeseries — Story 2.1 adds v2).
Future<void> onCreateV1(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user_preferences (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  await db.insert(
    'user_preferences',
    {
      'key': kDailyStepGoalKey,
      'value': kDefaultStepGoal.toString(),
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );

  await db.insert(
    'user_preferences',
    {
      'key': kThemeModeKey,
      'value': kDefaultThemeMode,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}
