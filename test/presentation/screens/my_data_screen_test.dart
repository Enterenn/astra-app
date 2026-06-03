import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/screens/my_data_screen.dart';
import 'package:astra_app/presentation/widgets/data_export_button.dart';
import 'package:astra_app/presentation/widgets/data_import_button.dart';
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
    super.isIos,
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
}) {
  return MyDataState(
    status: MyDataStatus.ready,
    sampleCount: 10,
    fileSizeBytes: 1024,
    backgroundStatus: BackgroundCollectionStatus.healthy,
    isIos: false,
    isExporting: isExporting,
    exportErrorMessage: exportErrorMessage,
    isImporting: isImporting,
    importErrorMessage: importErrorMessage,
    importSuccessPending: importSuccessPending,
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

    Future<void> pumpScreen(
      WidgetTester tester, {
      required MyDataCubit cubit,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: BlocProvider<MyDataCubit>.value(
              value: cubit,
              child: MyDataScreen(clock: clock),
            ),
          ),
        ),
      );
      await tester.pump();
    }

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
