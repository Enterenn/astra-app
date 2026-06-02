import 'dart:io';

import 'package:astra_app/core/database/isolate_database_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('openIsolateAstraDatabase', () {
    late Directory tempDir;
    late String databasePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('astra_isolate_db_test_');
      databasePath = '${tempDir.path}${Platform.pathSeparator}astra_test.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('opens separate file-backed WAL connections on the same path', () async {
      final first = await openIsolateAstraDatabase(databasePath: databasePath);
      addTearDown(first.close);

      final firstJournalMode = await first.rawQuery('PRAGMA journal_mode');
      expect(firstJournalMode.single.values.single.toString().toLowerCase(), 'wal');

      await first.close();

      final second = await openIsolateAstraDatabase(databasePath: databasePath);
      addTearDown(second.close);

      final secondJournalMode = await second.rawQuery('PRAGMA journal_mode');
      expect(secondJournalMode.single.values.single.toString().toLowerCase(), 'wal');
    });
  });
}
