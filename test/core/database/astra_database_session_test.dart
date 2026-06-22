import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraDatabaseSession', () {
    test('withRetry reopens after database_closed and succeeds', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'astra_db_session_test_',
      );

      final databasePath = p.join(tempDir.path, 'test.db');
      final db = await openAstraDatabase(databasePath: databasePath);
      final session = AstraDatabaseSession(
        databasePath: databasePath,
        initial: db,
      );
      addTearDown(() async {
        if (session.database.isOpen) {
          await session.database.close();
        }
        await tempDir.delete(recursive: true);
      });
      final repository = UserHealthMetricsRepository(session);
      await repository.setDisplayName('Ada');

      await session.database.close();

      final name = await repository.getDisplayName();
      expect(name, 'Ada');
      expect(session.database.isOpen, isTrue);
    });

    test('ensureOpen opens when handle was never initialized', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'astra_db_session_open_',
      );

      final databasePath = p.join(tempDir.path, 'test.db');
      final session = AstraDatabaseSession(databasePath: databasePath);
      addTearDown(() async {
        if (session.database.isOpen) {
          await session.database.close();
        }
        await tempDir.delete(recursive: true);
      });
      await session.ensureOpen();
      expect(session.database.isOpen, isTrue);
    });
  });
}
