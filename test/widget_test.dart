import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraApp navigation shell', () {
    late Database db;
    late AppDependencies deps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(
        db: db,
        userPreferences: userPreferences,
      );
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets('shows NavigationBar and switches tab placeholders', (
      WidgetTester tester,
    ) async {
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
      });

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('My Data'), findsOneWidget);

      expect(
        find.text('steps today'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(
        find.text(
          'No history yet. Walk a bit — data stays on this device.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Data footprint, export, and settings will appear here.'),
        findsOneWidget,
      );

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
            ),
          );
          await tester.pump();
        });

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);

        await tester.runAsync(() async {
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

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Your steps stay on this device.'), findsNothing);

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

      expect(find.text('Your steps stay on this device.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
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

      expect(find.text('Your steps stay on this device.'), findsOneWidget);

      await tester.runAsync(() async {
        await cubitRef!.completeOnboarding(goal: 8000);
      });
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Your steps stay on this device.'), findsNothing);
      expect(
        find.text('steps today'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
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
      });
    });
  });
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
