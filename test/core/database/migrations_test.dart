import 'dart:io';

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('migration v2 fresh install', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates user_preferences and timeseries_samples tables', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((row) => row['name'] as String).toList();

      expect(tableNames, contains('user_preferences'));
      expect(tableNames, contains('timeseries_samples'));
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

    test('creates canonical timeseries columns with required fields', () async {
      final columns = await db.rawQuery(
        'PRAGMA table_info(timeseries_samples);',
      );
      final columnByName = {
        for (final column in columns) column['name'] as String: column,
      };

      expect(
        columnByName.keys,
        containsAll(<String>[
          'id',
          'start_time',
          'end_time',
          'type',
          'value',
          'unit',
          'resolution',
          'provider',
          'device_id',
          'zone_offset',
        ]),
      );

      for (final columnName in <String>[
        'id',
        'start_time',
        'end_time',
        'type',
        'value',
        'unit',
        'resolution',
        'provider',
        'device_id',
        'zone_offset',
      ]) {
        expect(columnByName[columnName]?['notnull'], 1);
      }
    });

    test('creates query and unique bucket identity indexes', () async {
      final indexes = await db.rawQuery(
        'PRAGMA index_list(timeseries_samples);',
      );
      final indexByName = {
        for (final index in indexes) index['name'] as String: index,
      };

      expect(indexByName, contains('idx_timeseries_query'));
      expect(indexByName, contains('idx_bucket_identity'));
      expect(indexByName['idx_bucket_identity']?['unique'], 1);

      final queryIndexColumns = await db.rawQuery(
        'PRAGMA index_info(idx_timeseries_query);',
      );
      expect(
        queryIndexColumns.map((column) => column['name']),
        orderedEquals(<String>['type', 'start_time']),
      );

      final queryIndexMetadata = await db.rawQuery(
        'PRAGMA index_xinfo(idx_timeseries_query);',
      );
      final startTimeIndexColumn = queryIndexMetadata.firstWhere(
        (column) => column['name'] == 'start_time',
      );
      expect(startTimeIndexColumn['desc'], 1);

      final bucketIndexColumns = await db.rawQuery(
        'PRAGMA index_info(idx_bucket_identity);',
      );
      expect(
        bucketIndexColumns.map((column) => column['name']),
        orderedEquals(<String>[
          'provider',
          'device_id',
          'type',
          'start_time',
          'end_time',
          'resolution',
        ]),
      );
    });

    test('enforces non-negative and whole-number step values', () async {
      const validStepSample = {
        'id': '00000000-0000-4000-8000-000000000001',
        'start_time': '2026-06-02T08:00:00Z',
        'end_time': '2026-06-02T08:05:00Z',
        'type': 'steps',
        'value': 12,
        'unit': 'count',
        'resolution': '5min',
        'provider': 'internal_phone',
        'device_id': 'smartphone',
        'zone_offset': '+02:00',
      };

      await expectLater(
        db.insert('timeseries_samples', validStepSample),
        completes,
      );

      await expectLater(
        db.insert('timeseries_samples', {
          ...validStepSample,
          'id': '00000000-0000-4000-8000-000000000002',
          'start_time': '2026-06-02T08:05:00Z',
          'end_time': '2026-06-02T08:10:00Z',
          'value': -1,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        db.insert('timeseries_samples', {
          ...validStepSample,
          'id': '00000000-0000-4000-8000-000000000003',
          'start_time': '2026-06-02T08:10:00Z',
          'end_time': '2026-06-02T08:15:00Z',
          'value': 12.5,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        db.insert('timeseries_samples', {
          ...validStepSample,
          'id': '00000000-0000-4000-8000-000000000004',
          'start_time': '2026-06-02T08:15:00Z',
          'end_time': '2026-06-02T08:20:00Z',
          'value': 12.0,
        }),
        completes,
      );

      await expectLater(
        db.insert('timeseries_samples', {
          ...validStepSample,
          'id': null,
          'start_time': '2026-06-02T08:20:00Z',
          'end_time': '2026-06-02T08:25:00Z',
        }),
        throwsA(isA<DatabaseException>()),
      );

      await expectLater(
        db.insert('timeseries_samples', {
          ...validStepSample,
          'id': '00000000-0000-4000-8000-000000000005',
          'start_time': '2026-06-02T08:25:00Z',
          'end_time': '2026-06-02T08:30:00Z',
          'type': 'distance',
          'value': 'abc',
          'unit': 'meter',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('migration v1 direct target', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) => runMigrations(db, version),
      );
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
  });

  group('migration v1 to v2 upgrade', () {
    test('preserves custom preferences and adds timeseries schema', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'astra_db_upgrade_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final databasePath = p.join(tempDir.path, 'astra_app.db');
      final v1Db = await openDatabase(
        databasePath,
        version: 1,
        onCreate: (db, version) => runMigrations(db, version),
      );
      await v1Db.update(
        'user_preferences',
        {'value': '12000'},
        where: 'key = ?',
        whereArgs: [kDailyStepGoalKey],
      );
      await v1Db.update(
        'user_preferences',
        {'value': 'dark'},
        where: 'key = ?',
        whereArgs: [kThemeModeKey],
      );
      await v1Db.close();

      final upgradedDb = await openAstraDatabase(databasePath: databasePath);
      addTearDown(() => upgradedDb.close());

      final prefs = {
        for (final row in await upgradedDb.query('user_preferences'))
          row['key'] as String: row['value'] as String,
      };
      expect(prefs[kDailyStepGoalKey], '12000');
      expect(prefs[kThemeModeKey], 'dark');

      final tables = await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'timeseries_samples'",
      );
      expect(tables, isNotEmpty);

      final indexes = await upgradedDb.rawQuery(
        'PRAGMA index_list(timeseries_samples);',
      );
      final indexNames = indexes.map((index) => index['name'] as String);
      expect(
        indexNames,
        containsAll(['idx_timeseries_query', 'idx_bucket_identity']),
      );
    });
  });
}
