import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/csv/timeseries_csv_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/import_result.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import 'package:astra_app/core/time/time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/services/csv_service.dart';
import '../../helpers/step_test_fixtures.dart';

class _ImportDelayCsvService extends CsvService {
  _ImportDelayCsvService({
    required Database db,
    required TimeProvider clock,
    required this.importDelay,
  }) : super(db, clock: clock);

  final Duration importDelay;
  var importCalls = 0;

  @override
  Future<ImportResult> importSamples(
    List<TimeseriesSampleModel> samples,
  ) async {
    importCalls++;
    await Future<void>.delayed(importDelay);
    return super.importSamples(samples);
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit pickAndImport', () {
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
      tempDir = await Directory.systemTemp.createTemp('astra_cubit_import_');
    });

    tearDown(() async {
      await db.close();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold the exported CSV briefly.
      }
    });

    /// Exports one sample then clears DB so import runs without confirm.
    Future<String> buildValidCsvFile() async {
      await stepRepos.ingestion.insertDevSamplesBatch([
        TimeseriesSampleModel(
          id: '00000000-0000-4000-8000-000000000001',
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
          type: kStepSampleType,
          value: 100,
          unit: kStepSampleUnit,
          resolution: kFiveMinuteResolution,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      ]);
      final path = await stepRepos.csv.exportCsv(outputDirectory: tempDir.path);
      await db.delete('timeseries_samples');
      return path;
    }

    MyDataCubit buildCubit({
      PickCsvFileCallback? pickCsvFile,
      ConfirmImportCallback? confirmImport,
      PostImportRefreshCallback? postImportRefresh,
      StepAggregationRepository? stepAggregationOverride,
      CsvService? csvServiceOverride,
    }) {
      return MyDataCubit(
        stepAggregation: stepAggregationOverride ?? stepRepos.aggregation,
        csvService: csvServiceOverride ?? stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        pickCsvFile: pickCsvFile,
        confirmImport: confirmImport,
        postImportRefresh: postImportRefresh,
        isIos: false,
      );
    }

    test('sets isImporting while import is in flight', () async {
      final csvPath = await buildValidCsvFile();
      final delayingRepo = _ImportDelayCsvService(
        db: db,
        clock: clock,
        importDelay: const Duration(milliseconds: 50),
      );
      final cubit = buildCubit(
        csvServiceOverride: delayingRepo,
        pickCsvFile: () async => csvPath,
      );

      await cubit.refresh();
      final importFuture = cubit.pickAndImport();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.isImporting, isTrue);

      await importFuture;
      expect(cubit.state.isImporting, isFalse);
      expect(cubit.state.importError, isNull);

      await cubit.close();
    });

    test('ignores duplicate import while in flight', () async {
      final csvPath = await buildValidCsvFile();
      final delayingRepo = _ImportDelayCsvService(
        db: db,
        clock: clock,
        importDelay: const Duration(milliseconds: 50),
      );
      final cubit = buildCubit(
        csvServiceOverride: delayingRepo,
        pickCsvFile: () async => csvPath,
      );

      await cubit.refresh();
      final first = cubit.pickAndImport();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = cubit.pickAndImport();
      await Future.wait([first, second]);

      expect(delayingRepo.importCalls, 1);

      await cubit.close();
    });

    test('skips confirm when database is empty', () async {
      final csvPath = await buildValidCsvFile();

      var confirmCalls = 0;
      final cubit = buildCubit(
        pickCsvFile: () async => csvPath,
        confirmImport: (_, _) async {
          confirmCalls++;
          return true;
        },
      );

      await cubit.refresh();
      expect(cubit.state.sampleCount, 0);

      await cubit.pickAndImport();
      expect(confirmCalls, 0);

      await cubit.close();
    });

    test('awaits confirm when database has samples', () async {
      await stepRepos.ingestion.insertDevSamplesBatch([
        TimeseriesSampleModel(
          id: '00000000-0000-4000-8000-000000000001',
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
          type: kStepSampleType,
          value: 100,
          unit: kStepSampleUnit,
          resolution: kFiveMinuteResolution,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      ]);
      final csvPath = await stepRepos.csv.exportCsv(outputDirectory: tempDir.path);
      var confirmCalls = 0;

      final cubit = buildCubit(pickCsvFile: () async => csvPath);

      await cubit.refresh();
      await cubit.pickAndImport(
        confirmImport: (csvRows, existing) async {
          confirmCalls++;
          expect(csvRows, 1);
          expect(existing, 1);
          return false;
        },
      );

      expect(confirmCalls, 1);
      expect(cubit.state.isImporting, isFalse);
      expect(await stepRepos.aggregation.countStepSamples(), 1);

      await cubit.close();
    });

    test('emits validation error for bad header before import', () async {
      final badFile = File('${tempDir.path}/bad-header.csv');
      await badFile.writeAsString('not,a,valid,header\n');

      final cubit = buildCubit(pickCsvFile: () async => badFile.path);

      await cubit.refresh();
      await cubit.pickAndImport();

      expect(cubit.state.isImporting, isFalse);
      expect(cubit.state.importError, isNotNull);
      expect(cubit.state.importValidationDetail, contains('header'));

      await cubit.close();
    });

    test('header-only import does not set importSuccessPending', () async {
      final headerOnly = File('${tempDir.path}/header-only.csv');
      await headerOnly.writeAsString('${TimeseriesCsvCodec.headerRow}\n');

      final cubit = buildCubit(pickCsvFile: () async => headerOnly.path);

      await cubit.refresh();
      await cubit.pickAndImport();

      expect(cubit.state.importSuccessPending, isFalse);
      expect(cubit.state.importError, isNull);

      await cubit.close();
    });

    test('invokes postImportRefresh on success', () async {
      final csvPath = await buildValidCsvFile();
      var refreshCalls = 0;
      final cubit = buildCubit(
        pickCsvFile: () async => csvPath,
        postImportRefresh: () async {
          refreshCalls++;
        },
      );

      await cubit.refresh();
      await cubit.pickAndImport();
      expect(refreshCalls, 1);

      await cubit.close();
    });

    test('emits validation error message from ImportValidationException', () async {
      final badFile = File('${tempDir.path}/bad.csv');
      await badFile.writeAsString('${TimeseriesCsvCodec.headerRow}\ninvalid');

      final cubit = buildCubit(pickCsvFile: () async => badFile.path);

      await cubit.refresh();
      await cubit.pickAndImport();

      expect(cubit.state.isImporting, isFalse);
      expect(cubit.state.importError, isNotNull);
      expect(cubit.state.importValidationDetail, contains('Row'));

      await cubit.close();
    });

    test('refresh during import preserves isImporting', () async {
      final csvPath = await buildValidCsvFile();
      final delayingRepo = _ImportDelayCsvService(
        db: db,
        clock: clock,
        importDelay: const Duration(milliseconds: 50),
      );
      final cubit = buildCubit(
        csvServiceOverride: delayingRepo,
        pickCsvFile: () async => csvPath,
      );

      await cubit.refresh();
      final importFuture = cubit.pickAndImport();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.isImporting, isTrue);

      await cubit.refresh(silent: true);
      expect(cubit.state.isImporting, isTrue);

      await importFuture;
      expect(cubit.state.isImporting, isFalse);

      await cubit.close();
    });
  });
}
