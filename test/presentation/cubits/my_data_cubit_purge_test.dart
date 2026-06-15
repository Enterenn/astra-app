import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _TrackingStepRepository extends StepRepository {
  _TrackingStepRepository({required super.db, required super.clock});

  var purgeCalls = 0;

  @override
  Future<void> purge({
    Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  }) async {
    purgeCalls++;
    return super.purge(
      testHookAfterDeleteSamples: testHookAfterDeleteSamples,
    );
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit confirmAndPurge', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late _TrackingStepRepository stepRepository;
    late Directory tempDir;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = _TrackingStepRepository(db: db, clock: clock);
      tempDir = await Directory.systemTemp.createTemp('astra_cubit_purge_');
    });

    tearDown(() async {
      await db.close();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold exported CSV briefly.
      }
    });

    MyDataCubit buildCubit({
      PostPurgeRefreshCallback? postPurgeRefresh,
      ShareCsvFileCallback? shareCsvFile,
      SaveCsvFileCallback? saveCsvFile,
    }) {
      return MyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        isIos: false,
        activityPermissionGranted: () async => true,
        postPurgeRefresh: postPurgeRefresh,
        shareCsvFile: shareCsvFile ?? (_, {sharePositionOrigin}) async {},
        saveCsvFile: saveCsvFile ?? ((_) async => false),
        tempDirectoryProvider: () async => tempDir.path,
      );
    }

    test('deleteConfirmed clears lastOptimizedUtc after purge', () async {
      await userPreferences.setLastDatabaseOptimizedAt(
        DateTime.utc(2026, 6, 1),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(cubit.state.lastOptimizedUtc, isNotNull);

      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.deleteConfirmed,
      );

      expect(cubit.state.lastOptimizedUtc, isNull);
      expect(cubit.state.sampleCount, 0);
    });

    test('deleteConfirmed purges, refreshes, and sets success flag', () async {
      var refreshCalled = false;
      final cubit = buildCubit(
        postPurgeRefresh: () async {
          refreshCalled = true;
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.deleteConfirmed,
      );

      expect(stepRepository.purgeCalls, 1);
      expect(refreshCalled, isTrue);
      expect(cubit.state.isPurging, isFalse);
      expect(cubit.state.purgeSuccessPending, isTrue);
      expect(cubit.state.purgeErrorMessage, isNull);
    });

    test('cancelled action does not purge', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.cancelled,
      );

      expect(stepRepository.purgeCalls, 0);
      expect(cubit.state.purgeSuccessPending, isFalse);
    });

    test('exportFirst via callback does not purge', () async {
      var exportCalled = false;
      final cubit = buildCubit(
        shareCsvFile: (_, {sharePositionOrigin}) async {
          exportCalled = true;
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.exportFirst,
      );

      expect(stepRepository.purgeCalls, 0);
      expect(exportCalled, isTrue);
    });

    test('deleteConfirmed purges while export is in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isExporting: true));
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.deleteConfirmed,
      );

      expect(stepRepository.purgeCalls, 1);
      expect(cubit.state.purgeSuccessPending, isTrue);
    });

    test('blocks purge while export is in flight without dialog confirmation', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isExporting: true));
      await cubit.confirmAndPurge(
        confirmPurge: () async => PurgeConfirmAction.deleteConfirmed,
      );

      expect(stepRepository.purgeCalls, 0);
    });

    test('sets refresh error when purge succeeds but postPurgeRefresh fails', () async {
      final cubit = buildCubit(
        postPurgeRefresh: () async {
          throw StateError('refresh failed');
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.deleteConfirmed,
      );

      expect(stepRepository.purgeCalls, 1);
      expect(cubit.state.purgeSuccessPending, isFalse);
      expect(
        cubit.state.purgeErrorMessage,
        'All local data was removed, but the app could not refresh. Try again.',
      );
    });

    test('emits purge error message when repository fails', () async {
      final failingRepository = _FailingPurgeRepository(db: db, clock: clock);
      final cubit = MyDataCubit(
        stepRepository: failingRepository,
        userPreferences: userPreferences,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        isIos: false,
        shareCsvFile: (_, {sharePositionOrigin}) async {},
        saveCsvFile: (_) async => false,
        tempDirectoryProvider: () async => '',
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.confirmAndPurge(
        confirmedAction: PurgeConfirmAction.deleteConfirmed,
      );

      expect(cubit.state.purgeErrorMessage, isNotNull);
      expect(cubit.state.isPurging, isFalse);
    });
  });
}

class _FailingPurgeRepository extends StepRepository {
  _FailingPurgeRepository({required super.db, required super.clock});

  @override
  Future<void> purge({
    Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  }) async {
    throw StateError('purge failed');
  }
}
