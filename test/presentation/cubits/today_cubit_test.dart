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

    // ── Initial state, empty refresh, null ingestion, and coalesced refresh ──

    test('loading state, empty refresh, null ingestion not stale, and coalesced refresh', () async {
      // starts in loading
      final c0 = buildCubit();
      expect(c0.state.status, TodayStatus.loading);
      c0.close();

      // empty DB: empty status, zero steps, default goal, not stale, no ingestion
      final cubit = buildCubit();
      await cubit.refresh();
      expect(cubit.state.status, TodayStatus.empty);
      expect(cubit.state.steps, 0);
      expect(cubit.state.goal, kDefaultStepGoal);
      expect(cubit.state.isStale, isFalse);
      expect(cubit.state.lastIngestionUtc, isNull);
      cubit.close();

      // coalesced: two concurrent refresh() share one in-flight operation
      final permissionGate = Completer<bool>();
      final c2 = buildCubit(
        activityPermissionGranted: () => permissionGate.future,
      );
      final first = c2.refresh();
      final second = c2.refresh();
      permissionGate.complete(true);
      await Future.wait([first, second]);
      expect(c2.state.status, TodayStatus.empty);
      c2.close();
    });

    // ── noPermission: status, week strip populated, zero metrics, no celebration ──

    test('noPermission: status, weekDays populated, zero metrics, no celebration even with steps at goal', () async {
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

      expect(cubit.state.status, TodayStatus.noPermission);
      expect(cubit.state.weekDays, hasLength(7));
      expect(cubit.state.activityMetrics, ActivityMetricsSnapshot.zero);
      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    // ── Status transitions ──

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

    test('refresh status goalMet and overflow: both clamp progressRatio to 1', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.status, TodayStatus.goalMet);
      expect(c1.state.steps, 5000);
      expect(c1.state.progressRatio, 1);
      c1.close();

      // add more steps past the goal → overflow
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10, 10),
          value: 2500,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.status, TodayStatus.overflow);
      expect(c2.state.steps, 7500);
      expect(c2.state.progressRatio, 1);
      c2.close();
    });

    // ── Stale detection ──

    test('stale detection on Android: boundary (12 h, not stale) and just past (stale)', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 0),
          endTimeUtc: DateTime.utc(2026, 6, 2, 0),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final c1 = buildCubit(isIos: false);
      await c1.refresh();
      expect(c1.state.isStale, isFalse);
      c1.close();

      await db.delete('timeseries_samples');
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          endTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit(isIos: false);
      await c2.refresh();
      expect(c2.state.isStale, isTrue);
      c2.close();
    });

    test('stale detection on iOS: boundary (4 h, not stale) and just past (stale)', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final c1 = buildCubit(isIos: true);
      await c1.refresh();
      expect(c1.state.isStale, isFalse);
      c1.close();

      await db.delete('timeseries_samples');
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 7, 59),
          endTimeUtc: DateTime.utc(2026, 6, 2, 7, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit(isIos: true);
      await c2.refresh();
      expect(c2.state.isStale, isTrue);
      c2.close();
    });

    // ── Silent refresh ──

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
        if (state.status == TodayStatus.loading) sawLoading = true;
      });
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(sawLoading, isFalse);
      expect(cubit.state.status, TodayStatus.progress);
      await subscription.cancel();
      cubit.close();
    });

    // ── Celebration ──

    test('celebration triggers on goalMet and overflow when pref unset', () async {
      await userPreferences.setDailyStepGoal(5000);
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.showCelebration, isTrue);
      expect(
        await userPreferences.getCelebrationShownDate(),
        formatLocalDayIso(clock.snapshot()),
      );
      c1.close();

      // overflow also triggers celebration
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10, 10),
          value: 2500,
          zoneOffset: '+02:00',
        ),
      );
      // reset celebration pref so it can fire again
      await db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kCelebrationShownDateKey],
      );
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.showCelebration, isTrue);
      c2.close();
    });

    test('celebration does not trigger when steps below goal or pref already claimed today', () async {
      await userPreferences.setDailyStepGoal(5000);

      // steps below goal
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 3000,
          zoneOffset: '+02:00',
        ),
      );
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.showCelebration, isFalse);
      c1.close();

      // pref already claimed today
      final todayIso = formatLocalDayIso(clock.snapshot());
      await userPreferences.setCelebrationShownDate(todayIso);
      await db.delete('timeseries_samples');
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.showCelebration, isFalse);
      c2.close();
    });

    test('celebration: dismissCelebration clears flag, in-flight preserved on re-refresh, cleared after explicit dismiss', () async {
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

      // dismissCelebration immediately clears the flag
      cubit.dismissCelebration();
      expect(cubit.state.showCelebration, isFalse);

      // a re-refresh while pref already marked today re-triggers in-flight
      await db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kCelebrationShownDateKey],
      );
      await cubit.refresh();
      expect(cubit.state.showCelebration, isTrue);

      // another refresh with pref already today preserves in-flight celebration
      await cubit.refresh();
      expect(cubit.state.showCelebration, isTrue);

      // after dismiss, another refresh with pref today clears it permanently
      cubit.dismissCelebration();
      await cubit.refresh();
      expect(cubit.state.showCelebration, isFalse);
      cubit.close();
    });

    // ── Journal goal ──

    test('journal goal overrides stale prefs cache: progress resolved correctly, overflow when steps exceed journal goal', () async {
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
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.goal, 8000);
      expect(c1.state.status, TodayStatus.progress);
      expect(c1.state.showCelebration, isFalse);
      c1.close();

      // steps exceed journal goal → overflow
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10, 10),
          value: 2500,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.goal, 8000);
      expect(c2.state.status, TodayStatus.overflow);
      c2.close();
    });

    // ── Live stream ──

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

    // ── syncSteps ──

    test('syncSteps: monotonic merge and foregroundCatchUp flow', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      // monotonic merge: never regresses
      await cubit.syncSteps(1200);
      expect(cubit.state.steps, 1200);
      await cubit.syncSteps(1100);
      expect(cubit.state.steps, 1200);

      // foregroundCatchUp defers steps until clearForegroundCatchUp
      final stepsBeforeCatchUp = cubit.state.steps;
      await cubit.syncSteps(1500, foregroundCatchUp: true);
      expect(cubit.state.steps, stepsBeforeCatchUp);
      expect(cubit.state.catchUpTargetSteps, 1500);
      expect(cubit.state.foregroundCatchUp, isTrue);
      cubit.clearForegroundCatchUp();
      expect(cubit.state.foregroundCatchUp, isFalse);
      expect(cubit.state.catchUpTargetSteps, isNull);
      expect(cubit.state.steps, 1500);
      cubit.close();
    });

    // ── lastDisplayedSteps ──

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
      expect(cubit.state.lastDisplayedSteps, 4374);
      expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
      await cubit.syncSteps(4292, clampStaleDisplay: true);
      expect(await userPreferences.getLastDisplayedSteps(localDay), 4292);
      expect(cubit.state.lastDisplayedSteps, 4292);
      cubit.close();
    });

    test('refresh loads lastDisplayedSteps from prefs', () async {
      final localDay = formatLocalDayIso(clock.snapshot());
      await userPreferences.setLastDisplayedSteps(
        localDayIso: localDay,
        steps: 2500,
      );
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 1500,
          zoneOffset: '+02:00',
        ),
      );

      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
      expect(cubit.state.lastDisplayedSteps, 2500);
      cubit.close();
    });

    test('recordLastDisplayedSteps persists to prefs and updates state', () async {
      final cubit = buildCubit();
      await cubit.refresh();
      final localDay = formatLocalDayIso(clock.snapshot());

      await cubit.recordLastDisplayedSteps(1234);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.lastDisplayedSteps, 1234);
      expect(await userPreferences.getLastDisplayedSteps(localDay), 1234);
      cubit.close();
    });

    // ── Distance / activity metrics ──

    test('syncSteps distance: monotonic merge keeps metrics aligned', () async {
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

    // ── refreshMetadata ──

    test('refreshMetadata: updates stale flag and goal without changing steps', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          endTimeUtc: DateTime.utc(2026, 6, 1, 23, 59),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
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
      expect(cubit.state.isStale, isTrue);
      cubit.close();
    });

    // ── Week strip ──────────────────────────────────────────────────────────

    group('week strip', () {
      test('basics: 7 days loaded, today selected by default, selection changes on tap', () async {
        final cubit = buildCubit();
        await cubit.refresh();

        expect(cubit.state.weekDays, hasLength(7));
        expect(cubit.state.weekDays.first.weekdayLabel, 'MON');
        expect(cubit.state.weekDays.last.weekdayLabel, 'SUN');
        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);
        expect(today.dayNumber, 2);
        expect(today.weekdayLabel, 'TUE');
        expect(_sameDate(cubit.state.selectedLocalDay, today.localDay), isTrue);

        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);
        expect(_sameDate(cubit.state.selectedLocalDay, monday.localDay), isTrue);
        cubit.close();
      });

      test(
        'selectLocalDay resets display state before async reload completes',
        () async {
          await stepRepository.upsertIngestionBucket(
            _bucket(
              startTimeUtc: DateTime.utc(2026, 6, 1, 10),
              value: 6000,
              zoneOffset: '+02:00',
            ),
          );
          final localDay = formatLocalDayIso(clock.snapshot());
          await userPreferences.setLastDisplayedSteps(
            localDayIso: localDay,
            steps: 4374,
          );
          final cubit = buildCubit();
          await cubit.refresh();

          expect(cubit.state.lastDisplayedSteps, 4374);
          expect(cubit.state.lastDisplayedStepsLoaded, isTrue);

          final pastDay = cubit.state.weekDays.firstWhere((day) => !day.isToday);
          cubit.selectLocalDay(pastDay.localDay);

          expect(cubit.state.lastDisplayedStepsLoaded, isFalse);
          expect(cubit.state.lastDisplayedSteps, isNull);

          await pumpEventQueue();

          expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
          expect(cubit.state.lastDisplayedSteps, isNull);
          cubit.close();
        },
      );

      test('refreshMetadata and silent refresh both keep in-session selected day', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);

        await cubit.refreshMetadata();
        expect(_sameDate(cubit.state.selectedLocalDay, monday.localDay), isTrue);

        await cubit.refresh();
        expect(_sameDate(cubit.state.selectedLocalDay, monday.localDay), isTrue);
        cubit.close();
      });

      test('selectLocalDay ignores day outside current week and future day', () async {
        final cubit = buildCubit();
        await cubit.refresh();
        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);

        cubit.selectLocalDay(DateTime(2020, 1, 1));
        expect(_sameDate(cubit.state.selectedLocalDay, today.localDay), isTrue);

        final futureDay = cubit.state.weekDays.firstWhere((day) => day.isFuture);
        cubit.selectLocalDay(futureDay.localDay);
        expect(_sameDate(cubit.state.selectedLocalDay, today.localDay), isTrue);
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

    // ── Selected day display ────────────────────────────────────────────────

    group('selected day display', () {
      test('past-day select shows seeded steps and historical goal', () async {
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
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;

        cubit.selectLocalDay(monday.localDay);
        await pumpEventQueue();

        expect(cubit.state.steps, 6000);
        expect(cubit.state.goal, 5000);
        expect(cubit.state.status, TodayStatus.overflow);
        cubit.close();
      });

      test('live tick ignored while past day selected', () async {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 10),
            value: 6000,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);
        await pumpEventQueue();

        await cubit.syncSteps(5000);

        expect(cubit.state.steps, 6000);
        cubit.close();
      });

      test('today re-select applies live today truth', () async {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 10),
            value: 6000,
            zoneOffset: '+02:00',
          ),
        );
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        final today = cubit.state.weekDays.singleWhere((day) => day.isToday);
        cubit.selectLocalDay(monday.localDay);
        await pumpEventQueue();

        await cubit.syncSteps(5000);
        cubit.selectLocalDay(today.localDay);
        await pumpEventQueue();

        expect(cubit.state.steps, 5000);
        cubit.close();
      });

      test('celebration blocked when past day selected even if live crosses goal',
          () async {
        await userPreferences.setDailyStepGoal(5000);
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 10),
            value: 6000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);
        await pumpEventQueue();

        await cubit.syncSteps(6000);

        expect(cubit.state.showCelebration, isFalse);
        cubit.close();
      });

      test('todayEditableGoal returns today goal while viewing past day', () async {
        await db.insert('daily_goal_effective', {
          'effective_from_local_day': '2026-06-01',
          'goal': 5000,
        });
        await userPreferences.setDailyStepGoal(10000);
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 1, 10),
            value: 6000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();
        final monday = cubit.state.weekDays.first;
        cubit.selectLocalDay(monday.localDay);
        await pumpEventQueue();

        expect(cubit.state.goal, 5000);
        expect(await cubit.todayEditableGoal, 10000);
        cubit.close();
      });
    });

    // ── Activity metrics ────────────────────────────────────────────────────

    group('activity metrics', () {
      test('refresh computes distance, kcal and duration; syncSteps updates distance only', () async {
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
    });

    // ── updateDailyStepGoal ─────────────────────────────────────────────────

    group('updateDailyStepGoal', () {
      test('persists goal, refreshes state, and invokes postGoalUpdate', () async {
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
        expect(await cubit.updateDailyStepGoal(15000), isTrue);

        expect(cubit.state.goal, 15000);
        expect(await userPreferences.getDailyStepGoal(), 15000);
        expect(callbackCalled, isTrue);
        cubit.close();
      });

      test('rejects invalid goal and is no-op when goal unchanged', () async {
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

        // rejects invalid goal
        expect(await cubit.updateDailyStepGoal(999), isFalse);
        expect(cubit.state.goal, 8000);
        expect(await userPreferences.getDailyStepGoal(), 8000);

        // no-op when goal unchanged
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
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
