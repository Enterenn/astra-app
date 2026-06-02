import 'package:sqflite/sqflite.dart';

import '../constants/preference_keys.dart';

const kDbVersion = 2;

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
      case 2:
        await onCreateV2(db);
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

/// Migration v2: timeseries samples schema and indexes.
Future<void> onCreateV2(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS timeseries_samples (
      id TEXT PRIMARY KEY,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      type TEXT NOT NULL,
      value REAL NOT NULL CHECK (value >= 0),
      unit TEXT NOT NULL,
      resolution TEXT NOT NULL,
      provider TEXT NOT NULL,
      device_id TEXT NOT NULL,
      zone_offset TEXT NOT NULL,
      CHECK (type <> 'steps' OR value = CAST(value AS INTEGER))
    )
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_timeseries_query
      ON timeseries_samples (type, start_time DESC)
  ''');

  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_bucket_identity
      ON timeseries_samples (
        provider,
        device_id,
        type,
        start_time,
        end_time,
        resolution
      )
  ''');
}
