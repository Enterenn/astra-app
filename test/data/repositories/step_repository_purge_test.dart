import 'dart:io';

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('StepRepository.purge', () {
    late Database db;
    late StepRepository repository;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late Directory tempDir;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 10),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
      tempDir = await Directory.systemTemp.createTemp('astra_purge_');
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> seedHealthAndDerivedState() async {
      await repository.insertDevSamplesBatch([
        _sample(id: '00000000-0000-4000-8000-000000000001'),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          startOffsetMinutes: 5,
        ),
      ]);
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 1200,
      );
      await db.insert('user_preferences', {
        'key': kCelebrationShownDateKey,
        'value': '2026-06-02',
      });
      await db.insert('user_preferences', {
        'key': kIngestionCollectLockKey,
        'value': 'locked',
      });
      await db.insert('user_preferences', {
        'key': kLastDatabaseOptimizedAtKey,
        'value': '2026-06-01T08:00:00.000Z',
      });
    }

    Future<void> seedSetupPreferences() async {
      for (final entry in {
        kDailyStepGoalKey: '9500',
        kThemeModeKey: 'dark',
        kAccentPresetKey: 'magenta',
        kOnboardingCompleteKey: 'true',
        kDisplayNameKey: 'Baptiste',
      }.entries) {
        await db.insert(
          'user_preferences',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    Future<Map<String, String>> readAllPreferences() async {
      final rows = await db.query('user_preferences');
      return {for (final row in rows) row['key']! as String: row['value']! as String};
    }

    test('removes samples and derived prefs but preserves setup keys', () async {
      await seedHealthAndDerivedState();
      await seedSetupPreferences();

      await repository.purge();

      expect(await repository.countStepSamples(), 0);
      expect(await repository.getLastIngestionUtc(), isNull);

      final prefs = await readAllPreferences();
      expect(prefs.containsKey(kDailyStepGoalKey), isTrue);
      expect(prefs[kDailyStepGoalKey], '9500');
      expect(prefs[kThemeModeKey], 'dark');
      expect(prefs[kAccentPresetKey], 'magenta');
      expect(prefs[kOnboardingCompleteKey], 'true');
      expect(prefs[kDisplayNameKey], 'Baptiste');
      expect(
        prefs.keys.where((k) => k.startsWith('ingestion_baseline/')),
        isEmpty,
      );
      expect(prefs.containsKey(kCelebrationShownDateKey), isFalse);
      expect(prefs.containsKey(kIngestionCollectLockKey), isFalse);
      expect(prefs.containsKey(kLastDatabaseOptimizedAtKey), isFalse);
    });

    test('transaction rolls back on forced error mid-purge', () async {
      await seedHealthAndDerivedState();
      await seedSetupPreferences();
      final sampleCountBefore = await repository.countStepSamples();
      final prefsBefore = await readAllPreferences();

      await expectLater(
        () => repository.purge(
          testHookAfterDeleteSamples: (_) async {
            throw StateError('forced purge failure');
          },
        ),
        throwsStateError,
      );

      expect(await repository.countStepSamples(), sampleCountBefore);
      expect(await readAllPreferences(), prefsBefore);
    });

    test('export then purge then import restores chart daily aggregates', () async {
      final samples = [
        _sample(
          id: '00000000-0000-4000-8000-000000000001',
          startOffsetMinutes: 0,
          value: 50,
        ),
        _sample(
          id: '00000000-0000-4000-8000-000000000002',
          startOffsetMinutes: 60,
          value: 75,
        ),
      ];
      await repository.insertDevSamplesBatch(samples);

      final before = await repository.getChartDailyAggregates(days: 7);
      final exportPath = await repository.exportCsv(outputDirectory: tempDir.path);

      await repository.purge();
      expect(await repository.countStepSamples(), 0);

      await repository.importCsv(filePath: exportPath);

      final after = await repository.getChartDailyAggregates(days: 7);
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].localDay, before[i].localDay);
        expect(after[i].totalSteps, before[i].totalSteps);
      }
    });
  });
}

TimeseriesSampleModel _sample({
  required String id,
  int startOffsetMinutes = 0,
  int value = 100,
}) {
  final start = DateTime.utc(2026, 6, 2, 8, startOffsetMinutes);
  return TimeseriesSampleModel(
    id: id,
    startTimeUtc: start,
    endTimeUtc: start.add(const Duration(minutes: 5)),
    type: kStepSampleType,
    value: value,
    unit: kStepSampleUnit,
    resolution: kFiveMinuteResolution,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: '+02:00',
  );
}
