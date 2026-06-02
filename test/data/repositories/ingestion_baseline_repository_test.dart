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

    test('returns null when no baseline is stored', () async {
      expect(
        await repository.getBaseline(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
        ),
        isNull,
      );
    });

    test('stores and reads cumulative baselines per source', () async {
      await repository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 5010,
      );

      expect(
        await repository.getBaseline(
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
        ),
        5010,
      );
    });
  });
}
