import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/sqflite_test_helper.dart';
import 'core/time/fake_time_provider.dart';

TodayCubit _testTodayCubit(AppDependencies deps) {
  return TodayCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
    clock: deps.timeProvider,
    activityPermissionGranted: () async => true,
  );
}

HistoryCubit _testHistoryCubit(AppDependencies deps) {
  return HistoryCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
  );
}

MyDataCubit _testMyDataCubit(AppDependencies deps) {
  return MyDataCubit(
    stepRepository: deps.stepRepository,
    userPreferences: deps.userPreferences,
    clock: deps.timeProvider,
    databasePath: deps.databasePath,
    activityPermissionGranted: () async => true,
  );
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraApp navigation shell', () {
    late Database db;
    late AppDependencies deps;
    late FakeTimeProvider clock;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      final userPreferences = UserPreferencesRepository(db, clock: clock);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
      );
    });

    tearDownAll(() async {
      await db.close();
    });

    setUp(() => GoalRing.disableStepPersistence = true);
    tearDown(() => GoalRing.disableStepPersistence = false);

    testWidgets('shows AppBottomNav and switches three tabs', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            createMyDataCubit: _testMyDataCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
      });

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('TRENDS'), findsOneWidget);
      expect(find.text('MENU'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
      expect(find.text('DATA'), findsNothing);
      expect(find.text('PROFILE'), findsNothing);

      expect(
        find.text('Steps'),
        findsAtLeastNWidgets(1),
      );

      await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
      await tester.pump();
      const emptyHistoryCopy =
          'No history yet. Walk a bit — data stays on this device.';
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 50; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text(emptyHistoryCopy).evaluate().isNotEmpty) {
            return;
          }
        }
      });

      expect(find.text('Trends'), findsWidgets);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text(emptyHistoryCopy), findsOneWidget);

      await tester.tap(find.byIcon(PhosphorIconsRegular.list));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Informations'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Storage on this device'), findsNothing);
      expect(find.byIcon(PhosphorIconsFill.list), findsOneWidget);

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });
  });

  group('AstraApp cold-start theme', () {
    late Database db;
    late AppDependencies deps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setThemeMode(AstraThemePreference.dark);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
      );
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets(
      'MaterialApp themeMode reflects persisted theme on first frame',
      (WidgetTester tester) async {
        await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        });
      },
    );
  });

  group('AstraApp onboarding gate', () {
    late Database completeDb;
    late Database incompleteDb;
    late AppDependencies completeDeps;
    late AppDependencies incompleteDeps;

    setUpAll(() async {
      completeDb = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final completePrefs = UserPreferencesRepository(completeDb);
      await completePrefs.setOnboardingComplete(true);
      completeDeps = await AppDependencies.test(
        db: completeDb,
        userPreferences: completePrefs,
      );

      incompleteDb = await openAstraDatabase(
        databasePath: inMemoryDatabasePath,
      );
      final incompletePrefs = UserPreferencesRepository(incompleteDb);
      incompleteDeps = await AppDependencies.test(
        db: incompleteDb,
        userPreferences: incompletePrefs,
        initialOnboardingComplete: false,
      );
    });

    tearDownAll(() async {
      await completeDb.close();
      await incompleteDb.close();
    });

    testWidgets('shows shell after onboarding complete flag', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: completeDeps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
      });

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text('Your Health. Your Phone. Period.'), findsNothing);

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });

    testWidgets('shows onboarding when completion flag is absent', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: incompleteDeps,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
      });

      expect(find.text('Your Health. Your Phone. Period.'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('transitions to shell after onboarding completes', (
      tester,
    ) async {
      OnboardingCubit? cubitRef;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: incompleteDeps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            createOnboardingCubit: (repo) {
              cubitRef = OnboardingCubit(
                userPreferences: repo,
                permissionRequester: (_) async => PermissionStatus.granted,
              );
              return cubitRef!;
            },
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
      });

      expect(find.text('Your Health. Your Phone. Period.'), findsOneWidget);

      await tester.runAsync(() async {
        await cubitRef!.completeWithHeight();
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text('Your Health. Your Phone. Period.'), findsNothing);
      expect(find.text('Steps'), findsAtLeastNWidgets(1));

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });
  });

  group('AstraApp foreground backfill', () {
    late Database db;
    late AppDependencies deps;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      final clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      await userPreferences.setLastDatabaseOptimizedAt(clock.snapshot().nowUtc);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
        timeProvider: clock,
        ingestionSources: [
          _MutableStepSource([
            StepReading(
              cumulativeSteps: 10,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8),
            ),
            StepReading(
              cumulativeSteps: 15,
              observedAtUtc: DateTime.utc(2026, 6, 2, 8, 1),
            ),
          ]),
        ],
      );
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('collects once after cold start', (tester) async {
      // The backfill runs real async work (stream + SQLite I/O), so the whole
      // flow must execute in runAsync — the fake-async zone never pumps real
      // database completions and the test would hang otherwise.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
        final last = await _waitForIngestion(
          stepRepository,
          DateTime.utc(2026, 6, 2, 8, 5),
        );
        expect(last, DateTime.utc(2026, 6, 2, 8, 5));
        await _disposePumpedApp(tester);
      });
    });

    testWidgets('collects again when app resumes', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
        await _waitForIngestion(stepRepository, DateTime.utc(2026, 6, 2, 8, 5));

        final source = deps.ingestionSources.single as _MutableStepSource;
        source.readings = [
          StepReading(
            cumulativeSteps: 20,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 5),
          ),
          StepReading(
            cumulativeSteps: 30,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 6),
          ),
        ];

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final last = await _waitForIngestion(
          stepRepository,
          DateTime.utc(2026, 6, 2, 8, 10),
        );
        expect(last, DateTime.utc(2026, 6, 2, 8, 10));
        await _disposePumpedApp(tester);
      });
    });

    testWidgets('persists when app pauses before resume', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: _testTodayCubit,
            createHistoryCubit: _testHistoryCubit,
            enablePeriodicPersist: false,
            enableLiveStepPipeline: false,
          ),
        );
        await tester.pump();
        await _waitForIngestion(stepRepository, DateTime.utc(2026, 6, 2, 8, 5));

        final source = deps.ingestionSources.single as _MutableStepSource;
        source.readings = [
          StepReading(
            cumulativeSteps: 20,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 5),
          ),
          StepReading(
            cumulativeSteps: 30,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 6),
          ),
        ];

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        final lastOnPause = await _waitForIngestion(
          stepRepository,
          DateTime.utc(2026, 6, 2, 8, 10),
        );
        expect(lastOnPause, DateTime.utc(2026, 6, 2, 8, 10));
        await _disposePumpedApp(tester);
      });
    });

    testWidgets('refreshes Today cubit after resume once collect finishes', (
      tester,
    ) async {
      TodayCubit? todayCubit;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          AstraApp(
            deps: deps,
            createTodayCubit: (dependencies) {
              todayCubit = _testTodayCubit(dependencies);
              return todayCubit!;
            },
            createHistoryCubit: _testHistoryCubit,
          ),
        );
        await tester.pump();
        await _waitForIngestion(
          stepRepository,
          DateTime.utc(2026, 6, 2, 8, 5),
        );

        final stepsBeforeResume = await _waitForStableTodaySteps(todayCubit!);

        final source = deps.ingestionSources.single as _MutableStepSource;
        source.readings = [
          StepReading(
            cumulativeSteps: 20,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 5),
          ),
          StepReading(
            cumulativeSteps: 30,
            observedAtUtc: DateTime.utc(2026, 6, 2, 8, 6),
          ),
        ];

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _waitForIngestion(
          stepRepository,
          DateTime.utc(2026, 6, 2, 8, 10),
        );

        final stepsAfterResume = await _waitForStableTodaySteps(todayCubit!);
        expect(stepsAfterResume, greaterThan(stepsBeforeResume));
        await _disposePumpedApp(tester);
      });
    });
  });
}

Future<void> _disposePumpedApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

Future<int> _waitForStableTodaySteps(
  TodayCubit cubit, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (cubit.state.status != TodayStatus.loading) {
      return cubit.state.steps;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return cubit.state.steps;
}

/// Polls the repository until the latest ingestion reaches [expected] or a
/// short budget elapses, returning the last observed value either way.
///
/// The foreground backfill is fire-and-forget (`unawaited`), so tests cannot
/// await it directly; polling keeps the assertion deterministic without
/// arbitrary fixed delays.
Future<DateTime?> _waitForIngestion(
  StepRepository repository,
  DateTime expected,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await repository.getLastIngestionUtc() == expected) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return repository.getLastIngestionUtc();
}

class _MutableStepSource implements DataIngestionSource {
  _MutableStepSource(this.readings);

  List<StepReading> readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(readings);
}
