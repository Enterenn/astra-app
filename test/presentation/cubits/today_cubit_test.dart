import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/time/local_day_formatter.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('TodayCubit', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    TodayCubit buildCubit({
      Future<bool> Function()? activityPermissionGranted,
      bool isIos = false,
    }) {
      return TodayCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        clock: clock,
        activityPermissionGranted:
            activityPermissionGranted ?? () async => true,
        isIos: isIos,
      );
    }

    test('starts in loading state', () {
      final cubit = buildCubit();
      expect(cubit.state.status, TodayStatus.loading);
      cubit.close();
    });

    test('refresh emits noPermission when activity permission denied', () async {
      final cubit = buildCubit(activityPermissionGranted: () async => false);

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.noPermission);
      cubit.close();
    });

    test('refresh emits empty when permission granted and no steps', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.empty);
      expect(cubit.state.steps, 0);
      expect(cubit.state.goal, kDefaultStepGoal);
      expect(cubit.state.isStale, isFalse);
      cubit.close();
    });

    test('refresh emits progress when steps are below goal', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 3000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.progress);
      expect(cubit.state.steps, 3000);
      expect(cubit.state.progressRatio, closeTo(3000 / kDefaultStepGoal, 0.001));
      cubit.close();
    });

    test('refresh emits goalMet when steps equal goal', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.goalMet);
      expect(cubit.state.steps, 5000);
      expect(cubit.state.progressRatio, 1);
      cubit.close();
    });

    test('refresh emits overflow when steps exceed goal', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 7500,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.overflow);
      expect(cubit.state.steps, 7500);
      expect(cubit.state.progressRatio, 1);
      cubit.close();
    });

    test('refresh is not stale on Android at exactly 12 hours', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 0),
          endTimeUtc: DateTime.utc(2026, 6, 2, 0),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit(isIos: false);

      await cubit.refresh();

      expect(cubit.state.isStale, isFalse);
      cubit.close();
    });

    test('refresh is stale on Android just past 12 hours', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          endTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit(isIos: false);

      await cubit.refresh();

      expect(cubit.state.isStale, isTrue);
      cubit.close();
    });

    test('refresh is not stale on iOS at exactly 4 hours', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit(isIos: true);

      await cubit.refresh();

      expect(cubit.state.isStale, isFalse);
      cubit.close();
    });

    test('refresh is stale on iOS just past 4 hours', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 7, 59),
          endTimeUtc: DateTime.utc(2026, 6, 2, 7, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit(isIos: true);

      await cubit.refresh();

      expect(cubit.state.isStale, isTrue);
      cubit.close();
    });

    test('refresh is not stale when last ingestion is null', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.lastIngestionUtc, isNull);
      expect(cubit.state.isStale, isFalse);
      cubit.close();
    });

    test('silent refresh does not re-emit loading when data is already shown', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 3000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.progress);

      var sawLoading = false;
      final subscription = cubit.stream.listen((state) {
        if (state.status == TodayStatus.loading) {
          sawLoading = true;
        }
      });

      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(sawLoading, isFalse);
      expect(cubit.state.status, TodayStatus.progress);
      await subscription.cancel();
      cubit.close();
    });

    test('refresh triggers celebration when goal met and pref unset', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.showCelebration, isTrue);
      expect(
        await userPreferences.getCelebrationShownDate(),
        formatLocalDayIso(clock.snapshot()),
      );
      cubit.close();
    });

    test('refresh does not trigger celebration when pref already today', () async {
      final todayIso = formatLocalDayIso(clock.snapshot());
      await userPreferences.setCelebrationShownDate(todayIso);
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test('refresh does not trigger celebration when steps below goal', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 3000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test('refresh triggers celebration on overflow when pref unset', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 7500,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.showCelebration, isTrue);
      cubit.close();
    });

    test('refresh does not trigger celebration when permission denied', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit(activityPermissionGranted: () async => false);

      await cubit.refresh();

      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test('refresh preserves in-flight celebration when pref already today', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.showCelebration, isTrue);

      await cubit.refresh();

      expect(cubit.state.showCelebration, isTrue);
      cubit.close();
    });

    test('refresh clears celebration flag after dismiss when pref is today', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();
      cubit.dismissCelebration();

      await cubit.refresh();

      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test('dismissCelebration clears showCelebration flag', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.showCelebration, isTrue);
      cubit.dismissCelebration();
      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test('live stream updates steps without refresh', () async {
      final events = StreamController<PhoneStepEvent>.broadcast();
      final monitor = LiveStepMonitor(
        stepRepository: stepRepository,
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      final cubit = buildCubit();
      await cubit.refresh();
      cubit.attachLiveMonitor(monitor);
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 3500, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.steps, 3490);
      expect(cubit.state.status, TodayStatus.progress);
      await cubit.close();
      await monitor.stop();
      monitor.dispose();
      await events.close();
    });

    test('live stream triggers celebration when goal crossed', () async {
      await userPreferences.setDailyStepGoal(3000);
      final events = StreamController<PhoneStepEvent>.broadcast();
      final monitor = LiveStepMonitor(
        stepRepository: stepRepository,
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      final cubit = buildCubit();
      await cubit.refresh();
      cubit.attachLiveMonitor(monitor);
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      events.add(
        PhoneStepEvent(steps: 3100, timeStamp: DateTime.utc(2026, 6, 2, 12, 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.showCelebration, isTrue);
      expect(cubit.state.steps, 3000);
      await cubit.close();
      await monitor.stop();
      monitor.dispose();
      await events.close();
    });

    test('refreshMetadata updates stale without changing steps', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          endTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();
      final stepsBefore = cubit.state.steps;

      await cubit.refreshMetadata();

      expect(cubit.state.steps, stepsBefore);
      expect(cubit.state.isStale, isTrue);
      cubit.close();
    });

    test('coalesced refresh awaits a single in-flight operation', () async {
      final permissionGate = Completer<bool>();
      final cubit = buildCubit(
        activityPermissionGranted: () => permissionGate.future,
      );

      final first = cubit.refresh();
      final second = cubit.refresh();
      permissionGate.complete(true);

      await Future.wait([first, second]);

      expect(cubit.state.status, TodayStatus.empty);
      cubit.close();
    });
  });
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required int value,
  required String zoneOffset,
  DateTime? endTimeUtc,
  String provider = kInternalPhoneProvider,
  String deviceId = kSmartphoneDeviceId,
}) => NormalizedStepBucket(
  startTimeUtc: startTimeUtc,
  endTimeUtc: endTimeUtc ?? startTimeUtc.add(const Duration(minutes: 5)),
  value: value,
  provider: provider,
  deviceId: deviceId,
  zoneOffset: zoneOffset,
);
