@Tags(['critical'])
library;

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/data/repositories/_user_preferences_kv_store.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('UserPreferencesKvStore isDatabaseOpen', () {
    test('returns true when session is open', () async {
      final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      addTearDown(db.close);
      final session = AstraDatabaseSession(
        databasePath: inMemoryDatabasePath,
        initial: db,
      );
      final kv = UserPreferencesKvStore(session);

      expect(kv.isDatabaseOpen, isTrue);
    });

    test('returns false after database close without throwing', () async {
      final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final session = AstraDatabaseSession(
        databasePath: inMemoryDatabasePath,
        initial: db,
      );
      final kv = UserPreferencesKvStore(session);

      await db.close();
      expect(kv.isDatabaseOpen, isFalse);
    });

    test('returns false when session has no database handle', () {
      final session = AstraDatabaseSession(databasePath: inMemoryDatabasePath);
      final kv = UserPreferencesKvStore(session);

      expect(kv.isDatabaseOpen, isFalse);
    });
  });

  group('UserSettingsRepository isDatabaseOpen', () {
    test('delegates safe open predicate after close', () async {
      final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final settings = UserSettingsRepository(db);

      expect(settings.isDatabaseOpen, isTrue);
      await db.close();
      expect(settings.isDatabaseOpen, isFalse);
    });
  });
}
