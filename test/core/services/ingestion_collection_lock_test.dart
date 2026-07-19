@Tags(['slow'])
library;

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/core/services/ingestion_collection_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('IngestionCollectionLock', () {
    late AstraDatabaseSession session;

    setUp(() async {
      final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      session = AstraDatabaseSession(
        databasePath: inMemoryDatabasePath,
        initial: db,
      );
      await session.database.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kIngestionCollectLockKey],
      );
    });

    tearDown(() async {
      try {
        if (session.database.isOpen) {
          await session.database.close();
        }
      } on StateError {
        // _db null/closed — withRetry did not finish reopening (failing test path)
      }
    });

    test('tryAcquire succeeds when unlocked', () async {
      final lock = IngestionCollectionLock(session);
      expect(await lock.tryAcquire(), isTrue);
      await lock.release();
    });

    test('second acquire fails until release', () async {
      final first = IngestionCollectionLock(session);
      final second = IngestionCollectionLock(session);

      expect(await first.tryAcquire(), isTrue);
      expect(await second.tryAcquire(), isFalse);

      await first.release();
      expect(await second.tryAcquire(), isTrue);
      await second.release();
    });

    test('tryAcquire and release survive database_closed via withRetry', () async {
      final lock = IngestionCollectionLock(session);
      await session.database.close();

      expect(await lock.tryAcquire(), isTrue);
      expect(session.database.isOpen, isTrue);
      await lock.release();
    });
  });
}
