@Tags(['critical'])
library;

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('IngestionBaselineRepository.preferenceKey', () {
    test('keeps legacy key shape for controlled phone identifiers', () {
      expect(
        IngestionBaselineRepository.preferenceKey(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
        ),
        'ingestion_baseline/internal_phone/smartphone',
      );
    });

    test('avoids delimiter collisions for slash-bearing segments', () {
      final left = IngestionBaselineRepository.preferenceKey(
        provider: 'a/b',
        deviceId: 'c',
      );
      final right = IngestionBaselineRepository.preferenceKey(
        provider: 'a',
        deviceId: 'b/c',
      );

      expect(left, isNot(equals(right)));
      expect(left, 'ingestion_baseline/a%2Fb/c');
      expect(right, 'ingestion_baseline/a/b%2Fc');
    });
  });

  group('IngestionBaselineRepository', () {
    late Database db;
    late IngestionBaselineRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = IngestionBaselineRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('round-trips baseline for slash-bearing provider and deviceId', () async {
      const provider = 'wearable/vendor';
      const deviceId = 'aa:bb:cc/dd';

      await repository.setBaseline(
        provider: provider,
        deviceId: deviceId,
        cumulative: 4321,
      );

      final storedKey = IngestionBaselineRepository.preferenceKey(
        provider: provider,
        deviceId: deviceId,
      );
      final rows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [storedKey],
      );
      expect(rows, hasLength(1));
      expect(rows.single['value'], '4321');

      expect(
        await repository.getBaseline(provider: provider, deviceId: deviceId),
        4321,
      );
    });

    test('clearAllBaselines removes encoded keys inside txn', () async {
      await repository.setBaseline(
        provider: 'a/b',
        deviceId: 'c',
        cumulative: 100,
      );
      await repository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 200,
      );

      await db.transaction((txn) async {
        await IngestionBaselineRepository.clearAllBaselines(txn);
      });

      final rows = await db.query('user_preferences');
      expect(
        rows.where((row) => (row['key'] as String).startsWith('ingestion_baseline/')),
        isEmpty,
      );
    });
  });
}
