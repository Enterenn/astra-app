import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit exportAndShare', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;
    late Directory tempDir;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = StepRepository(db: db, clock: clock);
      tempDir = await Directory.systemTemp.createTemp('astra_cubit_export_');
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    MyDataCubit buildCubit({
      SaveCsvFileCallback? saveCsvFile,
      StepRepository? repository,
    }) {
      return MyDataCubit(
        stepRepository: repository ?? stepRepository,
        userPreferences: userPreferences,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        tempDirectoryProvider: () async => tempDir.path,
        saveCsvFile: saveCsvFile ?? ((_) async => true),
        isIos: false,
      );
    }

    test('sets isExporting while export is in flight', () async {
      final cubit = buildCubit(
        saveCsvFile: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return true;
        },
      );

      await cubit.refresh();
      expect(cubit.state.isExporting, isFalse);

      final exportFuture = cubit.exportAndShare();
      expect(cubit.state.isExporting, isTrue);

      await exportFuture;
      expect(cubit.state.isExporting, isFalse);
      expect(cubit.state.exportErrorMessage, isNull);

      await cubit.close();
    });

    test('ignores duplicate export while in flight', () async {
      var saveCalls = 0;
      final cubit = buildCubit(
        saveCsvFile: (_) async {
          saveCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return true;
        },
      );

      await cubit.refresh();
      final first = cubit.exportAndShare();
      final second = cubit.exportAndShare();

      await Future.wait([first, second]);
      expect(saveCalls, 1);

      await cubit.close();
    });

    test('emits exportErrorMessage when save fails', () async {
      final cubit = buildCubit(
        saveCsvFile: (_) async => throw StateError('save failed'),
      );

      await cubit.refresh();
      await cubit.exportAndShare();

      expect(cubit.state.isExporting, isFalse);
      expect(
        cubit.state.exportErrorMessage,
        'Export could not be completed. Try again.',
      );

      await cubit.close();
    });

    test('clears export error on successful export', () async {
      var saveCalls = 0;
      final cubit = buildCubit(
        saveCsvFile: (_) async {
          if (saveCalls == 0) {
            saveCalls++;
            throw StateError('save failed');
          }
          return true;
        },
      );

      await cubit.refresh();
      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNull);

      await cubit.close();
    });

    test('user cancel does not set export error', () async {
      final cubit = buildCubit(
        saveCsvFile: (_) async => false,
      );

      await cubit.refresh();
      await cubit.exportAndShare();

      expect(cubit.state.isExporting, isFalse);
      expect(cubit.state.exportErrorMessage, isNull);

      await cubit.close();
    });

    test('refresh during export preserves isExporting', () async {
      final cubit = buildCubit(
        saveCsvFile: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return true;
        },
      );

      await cubit.refresh();
      final exportFuture = cubit.exportAndShare();
      expect(cubit.state.isExporting, isTrue);

      await cubit.refresh(silent: true);
      expect(cubit.state.isExporting, isTrue);

      await exportFuture;
      expect(cubit.state.isExporting, isFalse);

      await cubit.close();
    });

    test('refresh during export error preserves exportErrorMessage', () async {
      final cubit = buildCubit(
        saveCsvFile: (_) async => throw StateError('save failed'),
      );

      await cubit.refresh();
      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.refresh(silent: true);
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.close();
    });

    test('writes CSV file before invoking save callback', () async {
      String? savedPath;
      var fileExistedDuringSave = false;
      final cubit = buildCubit(
        saveCsvFile: (path) async {
          savedPath = path;
          fileExistedDuringSave = File(path).existsSync();
          return true;
        },
      );

      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 3, 10),
          endTimeUtc: DateTime.utc(2026, 6, 3, 10, 5),
        ),
      );
      await cubit.refresh();
      await cubit.exportAndShare();

      expect(savedPath, isNotNull);
      expect(savedPath, contains('astra-export-2026-06-03.csv'));
      expect(fileExistedDuringSave, isTrue);
      expect(File(savedPath!).existsSync(), isFalse);

      await cubit.close();
    });
  });
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required DateTime endTimeUtc,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: endTimeUtc,
  value: 100,
  provider: kInternalPhoneProvider,
  deviceId: kSmartphoneDeviceId,
  zoneOffset: '+02:00',
);
