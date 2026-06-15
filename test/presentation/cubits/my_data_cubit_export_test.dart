import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _FixedCapabilityEvaluator extends BackgroundHealthCapabilityEvaluator {
  _FixedCapabilityEvaluator()
    : super(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => true,
        isAndroidPlatform: () => true,
      );

  @override
  Future<BackgroundHealthCapabilitySnapshot> evaluate() async {
    return const BackgroundHealthCapabilitySnapshot(
      activityRecognitionGranted: true,
      notificationGranted: true,
      batteryOptimizationExempt: true,
      fgsHealthDeclared: true,
      likelyOemBatteryDeferral: false,
    );
  }
}

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
      ShareCsvFileCallback? shareCsvFile,
      SaveCsvFileCallback? saveCsvFile,
      StepRepository? repository,
    }) {
      return MyDataCubit(
        stepRepository: repository ?? stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        tempDirectoryProvider: () async => tempDir.path,
        saveCsvFile: saveCsvFile ?? ((_) async => false),
        shareCsvFile: shareCsvFile ?? (_, {sharePositionOrigin}) async {},
        isIos: false,
      );
    }

    test('sets isExporting while export is in flight', () async {
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
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
      var shareCalls = 0;
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          shareCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
        },
      );

      await cubit.refresh();
      final first = cubit.exportAndShare();
      final second = cubit.exportAndShare();

      await Future.wait([first, second]);
      expect(shareCalls, 1);

      await cubit.close();
    });

    test('emits exportErrorMessage when share fails', () async {
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async =>
            throw StateError('share failed'),
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
      var shareCalls = 0;
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          if (shareCalls == 0) {
            shareCalls++;
            throw StateError('share failed');
          }
        },
      );

      await cubit.refresh();
      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNull);

      await cubit.close();
    });

    test('refresh during export preserves isExporting', () async {
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
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
        shareCsvFile: (_, {sharePositionOrigin}) async =>
            throw StateError('share failed'),
      );

      await cubit.refresh();
      await cubit.exportAndShare();
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.refresh(silent: true);
      expect(cubit.state.exportErrorMessage, isNotNull);

      await cubit.close();
    });

    test('forwards sharePositionOrigin to share callback', () async {
      Rect? capturedOrigin;
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          capturedOrigin = sharePositionOrigin;
        },
      );

      await cubit.refresh();
      const origin = Rect.fromLTWH(10, 20, 100, 48);
      await cubit.exportAndShare(sharePositionOrigin: origin);

      expect(capturedOrigin, origin);

      await cubit.close();
    });

    test('skips share when save to device succeeds', () async {
      var saveCalls = 0;
      var shareCalls = 0;
      final cubit = buildCubit(
        saveCsvFile: (path) async {
          saveCalls++;
          expect(File(path).existsSync(), isTrue);
          return true;
        },
        shareCsvFile: (_, {sharePositionOrigin}) async {
          shareCalls++;
        },
      );

      await cubit.refresh();
      await cubit.exportAndShare();

      expect(saveCalls, 1);
      expect(shareCalls, 0);
      expect(cubit.state.exportErrorMessage, isNull);

      await cubit.close();
    });

    test('writes CSV file before invoking share callback', () async {
      String? sharedPath;
      var fileExistedDuringShare = false;
      final cubit = buildCubit(
        shareCsvFile: (path, {sharePositionOrigin}) async {
          sharedPath = path;
          fileExistedDuringShare = File(path).existsSync();
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

      expect(sharedPath, isNotNull);
      expect(sharedPath, contains('astra-export-2026-06-03.csv'));
      // File must exist during the share callback.
      expect(fileExistedDuringShare, isTrue);
      // File must be deleted after share completes to protect health data.
      expect(File(sharedPath!).existsSync(), isFalse);

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
