import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/screens/my_data_screen.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:astra_app/presentation/widgets/data_export_button.dart';
import 'package:astra_app/presentation/widgets/data_import_button.dart';
import 'package:astra_app/presentation/widgets/data_purge_button.dart';
import 'package:astra_app/presentation/widgets/goal_editor_row.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// Widget tests seed UI state directly — no async refresh / DB reads (see app_scaffold_test).
class _SeededMyDataCubit extends MyDataCubit {
  _SeededMyDataCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.capabilityEvaluator,
    required super.clock,
    required super.databasePath,
    required MyDataState seededState,
  }) : _seededState = seededState {
    emit(seededState);
  }

  final MyDataState _seededState;

  @override
  Future<void> refresh({bool silent = true}) async {
    if (isClosed) {
      return;
    }
    emit(_seededState);
  }
}

MyDataState _readyState({
  bool isExporting = false,
  String? exportErrorMessage,
  bool isImporting = false,
  String? importErrorMessage,
  bool importSuccessPending = false,
  bool isPurging = false,
  String? purgeErrorMessage,
  bool purgeSuccessPending = false,
  int dailyStepGoal = 8000,
}) {
  return MyDataState(
    status: MyDataStatus.ready,
    sampleCount: 10,
    fileSizeBytes: 1024,
    backgroundStatus: BackgroundCollectionStatus.healthy,
    isIos: false,
    dailyStepGoal: dailyStepGoal,
    isExporting: isExporting,
    exportErrorMessage: exportErrorMessage,
    isImporting: isImporting,
    importErrorMessage: importErrorMessage,
    importSuccessPending: importSuccessPending,
    isPurging: isPurging,
    purgeErrorMessage: purgeErrorMessage,
    purgeSuccessPending: purgeSuccessPending,
  );
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataScreen export', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    MyDataCubit buildSeededCubit(MyDataState state) {
      return _SeededMyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
        seededState: state,
      );
    }

    ThemeCubit buildThemeCubit({
      AstraThemePreference initial = AstraThemePreference.system,
    }) {
      return ThemeCubit(
        userPreferences: userPreferences,
        initialPreference: initial,
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      required MyDataCubit cubit,
      ThemeCubit? themeCubit,
      bool disableAnimations = false,
    }) async {
      final theme = themeCubit ?? buildThemeCubit();
      if (themeCubit == null) {
        addTearDown(theme.close);
      }

      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<MyDataCubit>.value(value: cubit),
                  BlocProvider<ThemeCubit>.value(value: theme),
                ],
                child: MyDataScreen(clock: clock),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows Daily goal section with formatted value', (tester) async {
      final cubit = buildSeededCubit(_readyState(dailyStepGoal: 12000));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('Daily goal'), findsOneWidget);
      expect(find.byType(GoalEditorRow), findsOneWidget);
      expect(find.text('12\u2009000'), findsOneWidget);
    });

    testWidgets('tapping goal row opens editor sheet', (tester) async {
      final cubit = buildSeededCubit(_readyState(dailyStepGoal: 8000));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      await tester.tap(find.byType(GoalEditorRow));
      await tester.pumpAndSettle();

      expect(find.text('Daily step goal'), findsWidgets);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('goal row does not open editor while export in flight', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState(isExporting: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      final row = tester.widget<GoalEditorRow>(find.byType(GoalEditorRow));
      expect(row.onTap, isNull);

      await tester.tap(find.byType(GoalEditorRow));
      await tester.pump();

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('Appearance section sits between Daily goal and Your data', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.byType(ThemeSelector), findsOneWidget);

      final dailyGoalY = tester.getTopLeft(find.text('Daily goal')).dy;
      final appearanceY = tester.getTopLeft(find.text('Appearance')).dy;
      final yourDataY = tester.getTopLeft(find.text('Your data')).dy;

      expect(dailyGoalY < appearanceY, isTrue);
      expect(appearanceY < yourDataY, isTrue);
    });

    testWidgets('tapping Dark updates ThemeCubit and selector selection', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);
      final themeCubit = buildThemeCubit();
      addTearDown(themeCubit.close);

      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // SQLite + stream emit must run entirely in runAsync (see widget_test.dart).
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAstraLightTheme(),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<MyDataCubit>.value(value: cubit),
                BlocProvider<ThemeCubit>.value(value: themeCubit),
              ],
              child: Scaffold(body: MyDataScreen(clock: clock)),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(ThemeSelector),
            matching: find.text('Dark'),
          ),
        );
        await tester.pump();

        await themeCubit.stream
            .firstWhere(
              (state) => state.preference == AstraThemePreference.dark,
            )
            .timeout(const Duration(seconds: 2));
      });
      await tester.pump();

      expect(themeCubit.state.preference, AstraThemePreference.dark);
      expect(
        tester.getSemantics(find.text('Dark')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
    });

    testWidgets('theme selector disabled while export in flight', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState(isExporting: true));
      addTearDown(cubit.close);
      final themeCubit = buildThemeCubit();
      addTearDown(themeCubit.close);

      await pumpScreen(tester, cubit: cubit, themeCubit: themeCubit);

      final selector = tester.widget<ThemeSelector>(find.byType(ThemeSelector));
      expect(selector.enabled, isFalse);

      await tester.tap(find.text('Light'));
      await tester.pump();

      expect(themeCubit.state.preference, AstraThemePreference.system);
    });

    testWidgets('theme selector disabled while purge in flight', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState(isPurging: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      final selector = tester.widget<ThemeSelector>(find.byType(ThemeSelector));
      expect(selector.enabled, isFalse);
    });

    testWidgets('theme selector disabled while import in flight', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState(isImporting: true));
      addTearDown(cubit.close);
      final themeCubit = buildThemeCubit();
      addTearDown(themeCubit.close);

      await pumpScreen(tester, cubit: cubit, themeCubit: themeCubit);

      final selector = tester.widget<ThemeSelector>(find.byType(ThemeSelector));
      expect(selector.enabled, isFalse);

      await tester.tap(find.text('Light'));
      await tester.pump();

      expect(themeCubit.state.preference, AstraThemePreference.system);
    });

    testWidgets('shows Your data section with Export CSV button', (tester) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('Your data'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.byType(DataExportButton), findsOneWidget);
    });

    testWidgets('export button shows spinner and is disabled while exporting', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState(isExporting: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      final button = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byType(DataExportButton),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows Export saved snackbar for 3s after successful export', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      cubit.emit(_readyState(isExporting: true));
      await tester.pump();
      cubit.emit(_readyState(isExporting: false));
      await tester.pump();

      expect(find.text('Export saved'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 3));
    });

    testWidgets('shows Import CSV button below export', (tester) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('Import CSV'), findsOneWidget);
      expect(find.byType(DataImportButton), findsOneWidget);
    });

    testWidgets('import button shows spinner while importing', (tester) async {
      final cubit = buildSeededCubit(_readyState(isImporting: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(DataImportButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows Import complete snackbar for 3s after successful import', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      cubit.emit(_readyState());
      await tester.pump();
      cubit.emit(_readyState(importSuccessPending: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Import complete'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 3));
    });

    testWidgets('shows export error banner with retry tap', (tester) async {
      final cubit = _RetryExportMyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.text('Export could not be completed. Try again.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Export could not be completed. Try again.'),
      );
      await tester.pump();

      expect(cubit.exportAttempts, 1);
    });

    testWidgets('shows import error banner with retry tap', (tester) async {
      final cubit = _RetryImportMyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.text('Row 1: expected 10 columns'),
        findsOneWidget,
      );

      await tester.tap(find.text('Row 1: expected 10 columns'));
      await tester.pump();

      expect(cubit.importAttempts, 1);
    });

    testWidgets('shows Delete all local data purge button below import', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('Delete all local data'), findsOneWidget);
      expect(find.byType(DataPurgeButton), findsOneWidget);
    });

    testWidgets('purge button shows spinner while purging', (tester) async {
      final cubit = buildSeededCubit(_readyState(isPurging: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(DataPurgeButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows All local data removed snackbar for 3s after purge', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      cubit.emit(_readyState());
      await tester.pump();
      cubit.emit(_readyState(purgeSuccessPending: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('All local data removed'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 3));
    });

    testWidgets('shows purge error banner with retry tap', (tester) async {
      final cubit = _RetryPurgeMyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.text('Purge could not be completed. Try again.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Purge could not be completed. Try again.'),
      );
      await tester.pump();

      expect(cubit.purgeAttempts, 1);
    });

    testWidgets('delete anyway confirms purge while export from dialog is in flight', (
      tester,
    ) async {
      final cubit = _DialogPurgeFlowMyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit, disableAnimations: true);

      await tester.scrollUntilVisible(
        find.text('Delete all local data'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete all local data'));
      await tester.pump();
      expect(find.text('Export first'), findsOneWidget);

      await tester.tap(find.text('Export first'));
      await tester.pump();
      expect(cubit.state.isExporting, isTrue);

      await tester.tap(find.text('Delete anyway'));
      await tester.pump();
      await tester.pump();

      expect(cubit.confirmedPurgeWhileExporting, isTrue);
      expect(cubit.state.purgeSuccessPending, isTrue);
      expect(find.text('All local data removed'), findsOneWidget);
    });
  });
}

class _RetryImportMyDataCubit extends _SeededMyDataCubit {
  _RetryImportMyDataCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.capabilityEvaluator,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           importErrorMessage: 'Row 1: expected 10 columns',
         ),
       );

  int importAttempts = 0;

  @override
  Future<void> pickAndImport({ConfirmImportCallback? confirmImport}) async {
    importAttempts++;
  }
}

class _RetryExportMyDataCubit extends _SeededMyDataCubit {
  _RetryExportMyDataCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.capabilityEvaluator,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           exportErrorMessage: 'Export could not be completed. Try again.',
         ),
       );

  int exportAttempts = 0;

  @override
  Future<void> exportAndShare({Rect? sharePositionOrigin}) async {
    exportAttempts++;
  }
}

class _DialogPurgeFlowMyDataCubit extends _SeededMyDataCubit {
  _DialogPurgeFlowMyDataCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.capabilityEvaluator,
    required super.clock,
    required super.databasePath,
  }) : super(seededState: _readyState());

  var confirmedPurgeWhileExporting = false;

  @override
  Future<void> exportAndShare({Rect? sharePositionOrigin}) async {
    emit(_readyState(isExporting: true));
  }

  @override
  Future<void> confirmAndPurge({
    ConfirmPurgeCallback? confirmPurge,
    PurgeConfirmAction? confirmedAction,
  }) async {
    if (state.isExporting &&
        confirmedAction == PurgeConfirmAction.deleteConfirmed) {
      confirmedPurgeWhileExporting = true;
      emit(_readyState(isExporting: true, purgeSuccessPending: true));
    }
  }
}

class _RetryPurgeMyDataCubit extends _SeededMyDataCubit {
  _RetryPurgeMyDataCubit({
    required super.stepRepository,
    required super.userPreferences,
    required super.capabilityEvaluator,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           purgeErrorMessage: 'Purge could not be completed. Try again.',
         ),
       );

  int purgeAttempts = 0;

  @override
  Future<void> confirmAndPurge({
    ConfirmPurgeCallback? confirmPurge,
    PurgeConfirmAction? confirmedAction,
  }) async {
    purgeAttempts++;
  }
}
