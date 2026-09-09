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
      final stored = IngestionBaselineRepository.decodeSnapshot(
        rows.single['value'] as String,
      );
      expect(stored?.cumulative, 4321);
      expect(stored?.recordedAtUtc, isNotNull);

      expect(
        await repository.getBaseline(provider: provider, deviceId: deviceId),
        4321,
      );
      final snapshot = await repository.getBaselineSnapshot(
        provider: provider,
        deviceId: deviceId,
      );
      expect(snapshot?.cumulative, 4321);
      expect(snapshot?.recordedAtUtc, isNotNull);
    });

    test('reads legacy integer baseline without timestamp', () async {
      await db.insert('user_preferences', {
        'key': IngestionBaselineRepository.preferenceKey(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
        ),
        'value': '5000',
      });

      final snapshot = await repository.getBaselineSnapshot(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
      );
      expect(snapshot?.cumulative, 5000);
      expect(snapshot?.recordedAtUtc, isNull);
    });

    test('round-trips timestamped baseline snapshot', () async {
      final recordedAt = DateTime.utc(2026, 5, 30, 21, 50);
      await repository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 1000,
        recordedAtUtc: recordedAt,
      );

      final snapshot = await repository.getBaselineSnapshot(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
      );
      expect(snapshot?.cumulative, 1000);
      expect(snapshot?.recordedAtUtc, recordedAt);
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
