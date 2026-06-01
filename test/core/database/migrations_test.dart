import 'dart:io';

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('migration v1', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates only user_preferences table', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((row) => row['name'] as String).toList();

      expect(tableNames, contains('user_preferences'));
      expect(tableNames, isNot(contains('timeseries_samples')));
    });

    test('seeds default daily_step_goal and theme_mode', () async {
      final rows = await db.query('user_preferences');
      final prefs = {
        for (final row in rows) row['key'] as String: row['value'] as String,
      };

      expect(prefs[kDailyStepGoalKey], kDefaultStepGoal.toString());
      expect(prefs[kThemeModeKey], kDefaultThemeMode);
    });

    test('enables WAL journal mode on file-backed database', () async {
      final tempDir = await Directory.systemTemp.createTemp('astra_db_test');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final fileDb = await openAstraDatabase(
        databasePath: p.join(tempDir.path, 'astra_app.db'),
      );
      addTearDown(() => fileDb.close());

      final result = await fileDb.rawQuery('PRAGMA journal_mode;');
      expect(result.first['journal_mode'], 'wal');
    });

    test('enables foreign keys', () async {
      final result = await db.rawQuery('PRAGMA foreign_keys;');
      expect(result.first['foreign_keys'], 1);
    });
  });
}
