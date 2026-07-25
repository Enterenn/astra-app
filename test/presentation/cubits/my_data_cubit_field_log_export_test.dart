@Tags(['critical'])
library;

import 'dart:io';

import 'package:astra_app/core/debug/field_diagnostic_log.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit exportFieldDiagnosticLog', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late FakeTimeProvider clock;
    late StepTestRepos stepRepos;
    late Directory tempDir;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
      tempDir = await Directory.systemTemp.createTemp('astra_field_log_export_');
      fieldLogDirectoryProvider = () async => tempDir.path;
    });

    tearDown(() async {
      resetFieldDiagnosticLogForTests();
      await db.close();
      await tempDir.delete(recursive: true);
    });

    MyDataCubit buildCubit({
      SaveFieldLogFileCallback? saveFieldLogFile,
    }) {
      return MyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        tempDirectoryProvider: () async => tempDir.path,
        saveCsvFile: (_) async => true,
        saveFieldLogFile: saveFieldLogFile ?? ((_) async => true),
        pickCsvFile: () async => null,
        isIos: false,
      );
    }

    test('sets success pending when save succeeds', () async {
      final cubit = buildCubit();

      await cubit.refresh();
      await cubit.exportFieldDiagnosticLog();

      expect(cubit.state.isExportingFieldLog, isFalse);
      expect(cubit.state.fieldLogExportSuccessPending, isTrue);
      expect(cubit.state.fieldLogExportError, isNull);
      await cubit.close();
    });

    test('clears exporting flag when user cancels save dialog', () async {
      final cubit = buildCubit(saveFieldLogFile: (_) async => false);

      await cubit.refresh();
      await cubit.exportFieldDiagnosticLog();

      expect(cubit.state.isExportingFieldLog, isFalse);
      expect(cubit.state.fieldLogExportSuccessPending, isFalse);
      expect(cubit.state.fieldLogExportError, isNull);
      await cubit.close();
    });

    test('emits generic error when export preparation fails', () async {
      final cubit = MyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        tempDirectoryProvider: () async => throw StateError('no temp dir'),
        saveCsvFile: (_) async => true,
        saveFieldLogFile: (_) async => true,
        pickCsvFile: () async => null,
        isIos: false,
      );

      await cubit.refresh();
      await cubit.exportFieldDiagnosticLog();

      expect(cubit.state.isExportingFieldLog, isFalse);
      expect(cubit.state.fieldLogExportError, MyDataExportError.generic);
      await cubit.close();
    });
  });
}
