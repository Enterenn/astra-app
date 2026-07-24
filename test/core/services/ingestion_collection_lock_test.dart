@Tags(['slow'])
library;

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/core/services/ingestion_collection_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
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

    test('forMaintenance uses dedicated key separate from collection lock', () async {
      final collectionLock = IngestionCollectionLock(session);
      final maintenanceLock = IngestionCollectionLock.forMaintenance(session);

      expect(await collectionLock.tryAcquire(), isTrue);
      expect(await maintenanceLock.tryAcquire(), isFalse);

      await collectionLock.release();
      expect(await maintenanceLock.tryAcquire(), isTrue);

      final rows = await session.database.query(
        'user_preferences',
        where: 'key IN (?, ?)',
        whereArgs: [kIngestionCollectLockKey, kDatabaseMaintenanceLockKey],
      );
      expect(rows.length, 1);
      expect(rows.single['key'], kDatabaseMaintenanceLockKey);

      await maintenanceLock.release();
    });

    test('collection tryAcquire fails when maintenance lock held', () async {
      final maintenanceLock = IngestionCollectionLock.forMaintenance(session);
      final collectionLock = IngestionCollectionLock(session);

      expect(await maintenanceLock.tryAcquire(), isTrue);
      expect(await collectionLock.tryAcquire(), isFalse);

      await maintenanceLock.release();
      expect(await collectionLock.tryAcquire(), isTrue);
      await collectionLock.release();
    });

    test('forMaintenance TTL exceeds collection default', () {
      final maintenanceLock = IngestionCollectionLock.forMaintenance(session);
      final collectionLock = IngestionCollectionLock(session);

      expect(maintenanceLock.ttl, kDatabaseMaintenanceLockTtl);
      expect(maintenanceLock.ttl, greaterThan(collectionLock.ttl));
      expect(kDatabaseMaintenanceLockTtl.inMinutes, 10);
    });

    test('isHeld reflects non-expired and expired lock rows', () async {
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final lock = IngestionCollectionLock(
        session,
        lockKey: kDatabaseMaintenanceLockKey,
        ttl: const Duration(minutes: 5),
        clock: clock,
      );

      expect(
        await IngestionCollectionLock.isHeld(
          session,
          kDatabaseMaintenanceLockKey,
          clock: clock,
        ),
        isFalse,
      );

      expect(await lock.tryAcquire(), isTrue);
      expect(
        await IngestionCollectionLock.isHeld(
          session,
          kDatabaseMaintenanceLockKey,
          clock: clock,
        ),
        isTrue,
      );

      clock.setNowUtc(DateTime.utc(2026, 6, 2, 12, 6));
      expect(
        await IngestionCollectionLock.isHeld(
          session,
          kDatabaseMaintenanceLockKey,
          clock: clock,
        ),
        isFalse,
      );

      await lock.release();
    });
  });
}
