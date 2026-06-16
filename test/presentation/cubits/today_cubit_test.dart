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
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userPreferences = UserPreferencesRepository(db, clock: clock);
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

    test('refresh uses journal-resolved goal not stale prefs cache', () async {
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-02',
        'goal': 8000,
      });
      await db.update(
        'user_preferences',
        {'value': '5000'},
        where: 'key = ?',
        whereArgs: [kDailyStepGoalKey],
      );
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 6000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.goal, 8000);
      expect(cubit.state.status, TodayStatus.progress);
      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    test(
      'refresh emits goalMet when steps meet journal goal despite lower stale cache',
      () async {
        await db.insert('daily_goal_effective', {
          'effective_from_local_day': '2026-06-02',
          'goal': 8000,
        });
        await db.update(
          'user_preferences',
          {'value': '5000'},
          where: 'key = ?',
          whereArgs: [kDailyStepGoalKey],
        );
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 8500,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();

        await cubit.refresh();

        expect(cubit.state.goal, 8000);
        expect(cubit.state.status, TodayStatus.overflow);
        cubit.close();
      },
    );

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
      // ~12 min gap so +3490 credits fully under 5 steps/s rate limit (story 6.2).
      events.add(
        PhoneStepEvent(steps: 3500, timeStamp: DateTime.utc(2026, 6, 2, 12, 12)),
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
      // 10 min gap for +3000 delta under rate limit (story 6.2).
      events.add(
        PhoneStepEvent(steps: 3100, timeStamp: DateTime.utc(2026, 6, 2, 12, 10)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.showCelebration, isTrue);
      expect(cubit.state.steps, 3000);
      await cubit.close();
      await monitor.stop();
      monitor.dispose();
      await events.close();
    });

    test('refresh does not lower steps after live stream reported higher', () async {
      final events = StreamController<PhoneStepEvent>.broadcast();
      final monitor = LiveStepMonitor(
        stepRepository: stepRepository,
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      final cubit = buildCubit();
      cubit.attachLiveMonitor(monitor);
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      // 3.5 min gap for +1050 delta under rate limit (story 6.2).
      events.add(
        PhoneStepEvent(steps: 1150, timeStamp: DateTime.utc(2026, 6, 2, 12, 3, 30)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.steps, 1050);

      await cubit.refresh();
      expect(cubit.state.steps, greaterThanOrEqualTo(1050));

      await cubit.close();
      await monitor.stop();
      monitor.dispose();
      await events.close();
    });

    test('live stream updates steps while cubit is still loading', () async {
      final permissionGate = Completer<bool>();
      final events = StreamController<PhoneStepEvent>.broadcast();
      final monitor = LiveStepMonitor(
        stepRepository: stepRepository,
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      final cubit = buildCubit(
        activityPermissionGranted: () => permissionGate.future,
      );
      cubit.attachLiveMonitor(monitor);
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 10, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      // ~100 s gap for +490 delta under rate limit (story 6.2).
      events.add(
        PhoneStepEvent(steps: 500, timeStamp: DateTime.utc(2026, 6, 2, 12, 1, 40)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.steps, 490);
      expect(cubit.state.status, isNot(TodayStatus.loading));

      permissionGate.complete(true);
      await cubit.close();
      await monitor.stop();
      monitor.dispose();
      await events.close();
    });

    test('syncSteps applies monotonic merge from monitor', () async {
      final cubit = buildCubit();
      await cubit.refresh();
      await cubit.syncSteps(1200);
      expect(cubit.state.steps, 1200);
      await cubit.syncSteps(1100);
      expect(cubit.state.steps, 1200);
      cubit.close();
    });

    test('syncSteps foregroundCatchUp defers steps until clearForegroundCatchUp', () async {
      final cubit = buildCubit();
      await cubit.refresh();
      final stepsBeforeCatchUp = cubit.state.steps;
      await cubit.syncSteps(1200, foregroundCatchUp: true);
      expect(cubit.state.steps, stepsBeforeCatchUp);
      expect(cubit.state.catchUpTargetSteps, 1200);
      expect(cubit.state.foregroundCatchUp, isTrue);
      cubit.clearForegroundCatchUp();
      expect(cubit.state.foregroundCatchUp, isFalse);
      expect(cubit.state.catchUpTargetSteps, isNull);
      expect(cubit.state.steps, 1200);
      cubit.close();
    });

    test('refresh ignores stale-high lastDisplayed prefs in favor of SQLite', () async {
      final localDay = formatLocalDayIso(clock.snapshot());
      await stepRepository.upsertIngestionBucket(
        NormalizedStepBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 6),
          endTimeUtc: DateTime.utc(2026, 6, 2, 6, 5),
          value: 4292,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      );
      await userPreferences.setLastDisplayedSteps(
        localDayIso: localDay,
        steps: 4374,
      );

      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.steps, 4292);
      await cubit.syncSteps(4292, clampStaleDisplay: true);
      expect(await userPreferences.getLastDisplayedSteps(localDay), 4292);
      cubit.close();
    });

    test('syncSteps monotonic merge keeps distance aligned with display steps', () async {
      final cubit = buildCubit();
      await cubit.refresh();
      await cubit.syncSteps(1200);
      final distanceAt1200 = cubit.state.activityMetrics.distanceKm;
      expect(distanceAt1200, closeTo(0.912, 0.001));

      await cubit.syncSteps(1100);

      expect(cubit.state.steps, 1200);
      expect(cubit.state.activityMetrics.distanceKm, closeTo(distanceAt1200, 0.001));
      cubit.close();
    });

    test('refresh preserves distance when live steps exceed SQLite total', () async {
      final events = StreamController<PhoneStepEvent>.broadcast();
      final monitor = LiveStepMonitor(
        stepRepository: stepRepository,
        baselineRepository: IngestionBaselineRepository(db),
        clock: clock,
        stepEventStreamFactory: () => events.stream,
        emitThrottle: Duration.zero,
      );
      final cubit = buildCubit();
      cubit.attachLiveMonitor(monitor);
      await monitor.start();
      await monitor.reconcileFromDatabase();

      events.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 12)),
      );
      // 3.5 min gap for +1050 delta under rate limit (story 6.2).
      events.add(
        PhoneStepEvent(steps: 1150, timeStamp: DateTime.utc(2026, 6, 2, 12, 3, 30)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.steps, 1050);
      final distanceBefore = cubit.state.activityMetrics.distanceKm;
      expect(distanceBefore, closeTo(0.798, 0.001));

      await cubit.refresh();

      expect(cubit.state.steps, greaterThanOrEqualTo(1050));
      expect(
        cubit.state.activityMetrics.distanceKm,
        closeTo(distanceBefore, 0.001),
      );

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

    test('refreshMetadata updates goal without changing steps', () async {
      await userPreferences.setDailyStepGoal(8000);
      final cubit = buildCubit();
      await cubit.refresh();
      await cubit.syncSteps(5000);
      expect(cubit.state.goal, 8000);
      expect(cubit.state.steps, 5000);

      await userPreferences.setDailyStepGoal(4000);
      await cubit.refreshMetadata();

      expect(cubit.state.steps, 5000);
      expect(cubit.state.goal, 4000);
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

    group('week strip', () {
      test('selected day defaults to today after refresh', () async {
        final cubit = buildCubit();

        await cubit.refresh();

        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);
        expect(_sameDate(cubit.state.selectedLocalDay, today.localDay), isTrue);
        cubit.close();
      });

      test('selection changes on explicit day select', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;

        cubit.selectLocalDay(monday.localDay);

        expect(_sameDate(cubit.state.selectedLocalDay, monday.localDay), isTrue);
        cubit.close();
      });

      test('refreshMetadata keeps in-session selected day deterministic', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);

        await cubit.refreshMetadata();

        expect(_sameDate(cubit.state.selectedLocalDay, monday.localDay), isTrue);
        cubit.close();
      });

      test('selectLocalDay ignores future day', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);
        final futureDay = cubit.state.weekDays.firstWhere((day) => day.isFuture);

        cubit.selectLocalDay(futureDay.localDay);

        expect(_sameDate(cubit.state.selectedLocalDay, today.localDay), isTrue);
        cubit.close();
      });

      test('refresh loads seven calendar week days', () async {
        final cubit = buildCubit();

        await cubit.refresh();

        expect(cubit.state.weekDays, hasLength(7));
        expect(cubit.state.weekDays.first.weekdayLabel, 'MON');
        expect(cubit.state.weekDays.last.weekdayLabel, 'SUN');
        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);
        expect(today.dayNumber, 2);
        expect(today.weekdayLabel, 'TUE');
        cubit.close();
      });

      test('marks past day goalMet when steps meet daily goal', () async {
        await db.insert('daily_goal_effective', {
          'effective_from_local_day': '2026-06-01',
          'goal': 5000,
        });
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 10),
            value: 6000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();

        await cubit.refresh();

        final monday = cubit.state.weekDays.singleWhere(
          (day) => day.weekdayLabel == 'MON',
        );
        expect(monday.goalMet, isTrue);
        expect(monday.isFuture, isFalse);
        cubit.close();
      });

      test('noPermission still loads week strip', () async {
        final cubit = buildCubit(
          activityPermissionGranted: () async => false,
        );

        await cubit.refresh();

        expect(cubit.state.status, TodayStatus.noPermission);
        expect(cubit.state.weekDays, hasLength(7));
        cubit.close();
      });

      test('goalMet respects per-day goals after mid-week change', () async {
        await db.insert('daily_goal_effective', {
          'effective_from_local_day': '2026-06-08',
          'goal': 8000,
        });
        await db.insert('daily_goal_effective', {
          'effective_from_local_day': '2026-06-11',
          'goal': 10000,
        });
        clock.setNowUtc(DateTime.utc(2026, 6, 11, 12));
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 8, 10),
            value: 8500,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 10, 10),
            value: 8500,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 11, 10),
            value: 5000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();

        await cubit.refresh();

        final monday = cubit.state.weekDays.singleWhere(
          (day) => day.weekdayLabel == 'MON',
        );
        final wednesday = cubit.state.weekDays.singleWhere(
          (day) => day.weekdayLabel == 'WED',
        );
        final thursday = cubit.state.weekDays.singleWhere(
          (day) => day.weekdayLabel == 'THU',
        );
        expect(monday.goalMet, isTrue);
        expect(wednesday.goalMet, isTrue);
        expect(thursday.goalMet, isFalse);
        expect(thursday.isToday, isTrue);
        expect(cubit.state.goal, 10000);
        cubit.close();
      });
    });

    group('activity metrics', () {
      test('refresh computes distance kcal and duration from buckets', () async {
        await userPreferences.setHeightCm(175);
        await userPreferences.setWeightKg(70);
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 500,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();

        await cubit.refresh();

        expect(cubit.state.heightCm, 175);
        expect(cubit.state.weightKg, 70);
        expect(cubit.state.activityMetrics.distanceKm, closeTo(0.362, 0.001));
        expect(
          cubit.state.activityMetrics.walkingDuration,
          const Duration(minutes: 5),
        );
        expect(cubit.state.activityMetrics.kcal, 21);
        cubit.close();
      });

      test('syncSteps updates distance only preserving bucket metrics', () async {
        await userPreferences.setHeightCm(175);
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 500,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();

        final kcalBefore = cubit.state.activityMetrics.kcal;
        final durationBefore = cubit.state.activityMetrics.walkingDuration;

        await cubit.syncSteps(10000);

        expect(cubit.state.steps, 10000);
        expect(cubit.state.activityMetrics.distanceKm, closeTo(7.245, 0.001));
        expect(cubit.state.activityMetrics.kcal, kcalBefore);
        expect(cubit.state.activityMetrics.walkingDuration, durationBefore);
        cubit.close();
      });

      test('refreshMetadata reloads buckets for kcal and duration', () async {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 50,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        expect(cubit.state.activityMetrics.kcal, 2);

        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10, 5),
            value: 500,
            zoneOffset: '+02:00',
          ),
        );
        await cubit.refreshMetadata();

        expect(cubit.state.activityMetrics.kcal, 24);
        expect(
          cubit.state.activityMetrics.walkingDuration,
          const Duration(minutes: 5, seconds: 30),
        );
        cubit.close();
      });

      test('refreshMetadata applies updated height to distance', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        await cubit.syncSteps(10000);
        final defaultDistance = cubit.state.activityMetrics.distanceKm;

        await userPreferences.setHeightCm(175);
        await cubit.refreshMetadata();

        expect(cubit.state.heightCm, 175);
        expect(
          cubit.state.activityMetrics.distanceKm,
          closeTo(7.245, 0.001),
        );
        expect(
          cubit.state.activityMetrics.distanceKm,
          isNot(closeTo(defaultDistance, 0.001)),
        );
        cubit.close();
      });

      test('noPermission exposes zero metrics', () async {
        final cubit = buildCubit(
          activityPermissionGranted: () async => false,
        );

        await cubit.refresh();

        expect(cubit.state.activityMetrics, ActivityMetricsSnapshot.zero);
        cubit.close();
      });
    });

    group('updateDailyStepGoal', () {
      test('persists goal and refreshes state', () async {
        final cubit = buildCubit();

        await cubit.refresh();
        expect(await cubit.updateDailyStepGoal(15000), isTrue);

        expect(cubit.state.goal, 15000);
        expect(await userPreferences.getDailyStepGoal(), 15000);
        cubit.close();
      });

      test('invokes postGoalUpdate on successful update', () async {
        var callbackCalled = false;
        final cubit = TodayCubit(
          stepRepository: stepRepository,
          userPreferences: userPreferences,
          clock: clock,
          activityPermissionGranted: () async => true,
          postGoalUpdate: () async {
            callbackCalled = true;
          },
        );

        await cubit.refresh();
        expect(await cubit.updateDailyStepGoal(9000), isTrue);

        expect(callbackCalled, isTrue);
        cubit.close();
      });

      test('rejects invalid goal', () async {
        await userPreferences.setDailyStepGoal(8000);
        final cubit = buildCubit();

        await cubit.refresh();
        expect(await cubit.updateDailyStepGoal(999), isFalse);

        expect(cubit.state.goal, 8000);
        expect(await userPreferences.getDailyStepGoal(), 8000);
        cubit.close();
      });

      test('no-op when goal unchanged', () async {
        var callbackCalled = false;
        await userPreferences.setDailyStepGoal(8000);
        final cubit = TodayCubit(
          stepRepository: stepRepository,
          userPreferences: userPreferences,
          clock: clock,
          activityPermissionGranted: () async => true,
          postGoalUpdate: () async {
            callbackCalled = true;
          },
        );

        await cubit.refresh();
        expect(await cubit.updateDailyStepGoal(8000), isFalse);

        expect(callbackCalled, isFalse);
        cubit.close();
      });

      test('returns false when postGoalUpdate throws', () async {
        final cubit = TodayCubit(
          stepRepository: stepRepository,
          userPreferences: userPreferences,
          clock: clock,
          activityPermissionGranted: () async => true,
          postGoalUpdate: () async {
            throw StateError('refresh failed');
          },
        );

        await cubit.refresh();
        expect(await cubit.updateDailyStepGoal(12000), isFalse);

        expect(cubit.state.goal, 8000);
        expect(await userPreferences.getDailyStepGoal(), 12000);
        cubit.close();
      });
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

bool _sameDate(DateTime? a, DateTime b) {
  if (a == null) {
    return false;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
