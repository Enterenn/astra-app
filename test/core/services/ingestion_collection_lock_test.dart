import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/ingestion_collection_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('IngestionCollectionLock', () {
    late Database db;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      await db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kIngestionCollectLockKey],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('tryAcquire succeeds when unlocked', () async {
      final lock = IngestionCollectionLock(db);
      expect(await lock.tryAcquire(), isTrue);
      await lock.release();
    });

    test('second acquire fails until release', () async {
      final first = IngestionCollectionLock(db);
      final second = IngestionCollectionLock(db);

      expect(await first.tryAcquire(), isTrue);
      expect(await second.tryAcquire(), isFalse);

      await first.release();
      expect(await second.tryAcquire(), isTrue);
      await second.release();
    });
  });
}
