import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_errors.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/screens/my_data_screen.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:astra_app/presentation/widgets/background_status_card.dart';
import 'package:astra_app/presentation/widgets/data_export_button.dart';
import 'package:astra_app/presentation/widgets/data_import_button.dart';
import 'package:astra_app/presentation/widgets/data_purge_button.dart';
import 'package:astra_app/presentation/widgets/display_name_editor_row.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/l10n_test_helper.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

/// Widget tests seed UI state directly — no async refresh / DB reads (see app_scaffold_test).
class _SeededMyDataCubit extends MyDataCubit {
  _SeededMyDataCubit({
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
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
  MyDataExportError? exportError,
  bool exportSuccessPending = false,
  bool isImporting = false,
  MyDataImportError? importError,
  String? importValidationDetail,
  bool importSuccessPending = false,
  bool isPurging = false,
  MyDataPurgeError? purgeError,
  bool purgeSuccessPending = false,
  bool isIos = false,
  BackgroundCollectionStatus backgroundStatus =
      BackgroundCollectionStatus.healthy,
  DateTime? lastIngestionUtc,
  DateTime? lastOptimizedUtc,
  int sampleCount = 10,
  int fileSizeBytes = 1024,
}) {
  return MyDataState(
    status: MyDataStatus.ready,
    sampleCount: sampleCount,
    fileSizeBytes: fileSizeBytes,
    lastOptimizedUtc: lastOptimizedUtc,
    lastIngestionUtc: lastIngestionUtc,
    backgroundStatus: backgroundStatus,
    isIos: isIos,
    isExporting: isExporting,
    exportError: exportError,
    exportSuccessPending: exportSuccessPending,
    isImporting: isImporting,
    importError: importError,
    importValidationDetail: importValidationDetail,
    importSuccessPending: importSuccessPending,
    isPurging: isPurging,
    purgeError: purgeError,
    purgeSuccessPending: purgeSuccessPending,
  );
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  late Database db;
  late UserSettingsRepository userSettings;
  late UserHealthMetricsRepository userHealthMetrics;
  late FakeTimeProvider clock;
  late StepTestRepos stepRepos;

  setUp(() async {
    db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    userSettings = UserSettingsRepository(db);
    userHealthMetrics = UserHealthMetricsRepository(db);
    clock = FakeTimeProvider(
      fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
      zoneOffset: const Duration(hours: 2),
    );
    stepRepos = StepTestFixtures.create(db: db, clock: clock);
  });

  tearDown(() async {
    await db.close();
  });

  MyDataCubit buildSeededCubit(MyDataState state) {
    return _SeededMyDataCubit(
      stepAggregation: stepRepos.aggregation,
      csvService: stepRepos.csv,
      stepIngestion: stepRepos.ingestion,
      userSettings: userSettings,
      userHealthMetrics: userHealthMetrics,
      clock: clock,
      databasePath: inMemoryDatabasePath,
      seededState: state,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required MyDataCubit cubit,
    bool disableAnimations = false,
    Size viewSize = const Size(800, 1200),
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: BlocProvider<MyDataCubit>.value(
              value: cubit,
              child: const MyDataScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('MyDataScreen layout', () {
    testWidgets('shows My Data title and three mockup sections', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text(l10n.menuPrivacyAndData), findsOneWidget);
      expect(find.text(l10n.menuTrackingStatus), findsOneWidget);
      expect(find.text(l10n.myDataFootprint), findsOneWidget);
      expect(find.text(l10n.myDataYourData), findsOneWidget);
      expect(find.text('Storage on this device'), findsNothing);
      expect(find.text('Backup & restore'), findsNothing);
      expect(find.text('Step tracking'), findsNothing);

      expect(find.byType(ThemeSelector), findsNothing);
      expect(find.byType(DisplayNameEditorRow), findsNothing);
    });

    testWidgets('shows My Data screen title with semantics label', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text(l10n.menuPrivacyAndData), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MyDataScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == l10n.menuPrivacyAndData,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sections appear in Background → Footprint → Your data order', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      final backgroundY = tester.getTopLeft(find.text(l10n.menuTrackingStatus)).dy;
      final footprintY = tester.getTopLeft(find.text(l10n.myDataFootprint)).dy;
      final yourDataY = tester.getTopLeft(find.text(l10n.myDataYourData)).dy;

      expect(backgroundY < footprintY, isTrue);
      expect(footprintY < yourDataY, isTrue);
    });

    testWidgets('Background section shows healthy status card', (tester) async {
      final cubit = buildSeededCubit(
        _readyState(
          lastIngestionUtc: DateTime.utc(2026, 6, 3, 11, 30),
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(BackgroundStatusCard), findsOneWidget);
      expect(
        find.textContaining('Background collection active'),
        findsOneWidget,
      );
    });

    testWidgets('Footprint section shows formatted sample count', (tester) async {
      final cubit = buildSeededCubit(_readyState(sampleCount: 42));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text('42'), findsOneWidget);
      expect(find.text(l10n.myDataFootprintSamplesStored), findsOneWidget);
    });

    testWidgets('stale state shows full stale banner above Background card', (
      tester,
    ) async {
      final cubit = buildSeededCubit(
        _readyState(
          backgroundStatus: BackgroundCollectionStatus.stale,
        ),
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.textContaining('No new steps in 12+ hours'),
        findsOneWidget,
      );

      final bannerY = tester.getTopLeft(
        find.textContaining('No new steps in 12+ hours'),
      ).dy;
      final backgroundY = tester.getTopLeft(find.text(l10n.menuTrackingStatus)).dy;
      expect(bannerY < backgroundY, isTrue);
    });
  });

  group('MyDataScreen sovereignty flows', () {
    testWidgets('shows Export CSV button in Your data section', (tester) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text(l10n.myDataExportCsv), findsOneWidget);
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

    testWidgets(
      'shows Export saved snackbar for 3s after successful export',
      (tester) async {
        final cubit = buildSeededCubit(_readyState());
        addTearDown(cubit.close);

        await pumpScreen(tester, cubit: cubit);

        cubit.emit(_readyState());
        await tester.pump();
        cubit.emit(_readyState(exportSuccessPending: true));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.myDataExportSaved), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 3));
        expect(cubit.state.exportSuccessPending, isFalse);
      },
    );

    testWidgets('does not show Export saved snackbar when export is cancelled', (
      tester,
    ) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      cubit.emit(_readyState(isExporting: true));
      await tester.pump();
      cubit.emit(
        _readyState(
          isExporting: false,
          exportSuccessPending: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.myDataExportSaved), findsNothing);
      expect(cubit.state.exportSuccessPending, isFalse);
    });

    testWidgets('shows Import CSV button below export', (tester) async {
      final cubit = buildSeededCubit(_readyState());
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.text(l10n.myDataImportCsv), findsOneWidget);
      expect(find.byType(DataImportButton), findsOneWidget);
    });

    testWidgets('import button shows spinner while importing', (tester) async {
      final cubit = buildSeededCubit(_readyState(isImporting: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(DataImportButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets(
      'shows Import complete snackbar and clears importSuccessPending',
      (tester) async {
        final cubit = buildSeededCubit(_readyState());
        addTearDown(cubit.close);

        await pumpScreen(tester, cubit: cubit);

        cubit.emit(_readyState());
        await tester.pump();
        cubit.emit(_readyState(importSuccessPending: true));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.myDataImportComplete), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 3));
        expect(cubit.state.importSuccessPending, isFalse);
      },
    );

    testWidgets('shows export error banner with retry tap', (tester) async {
      final cubit = _RetryExportMyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.text(l10n.myDataExportErrorGeneric),
        findsOneWidget,
      );

      await tester.tap(
        find.text(l10n.myDataExportErrorGeneric),
      );
      await tester.pump();

      expect(cubit.exportAttempts, 1);
    });

    testWidgets('shows import error banner with retry tap', (tester) async {
      final cubit = _RetryImportMyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
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

      expect(find.text(l10n.myDataDeleteAllLocalData), findsOneWidget);
      expect(find.byType(DataPurgeButton), findsOneWidget);
    });

    testWidgets('purge button shows spinner while purging', (tester) async {
      final cubit = buildSeededCubit(_readyState(isPurging: true));
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(find.byType(DataPurgeButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets(
      'shows All local data removed snackbar and clears purgeSuccessPending',
      (tester) async {
        final cubit = buildSeededCubit(_readyState());
        addTearDown(cubit.close);

        await pumpScreen(tester, cubit: cubit);

        cubit.emit(_readyState());
        await tester.pump();
        cubit.emit(_readyState(purgeSuccessPending: true));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.myDataPurgeSuccess), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, const Duration(seconds: 3));
        expect(cubit.state.purgeSuccessPending, isFalse);
      },
    );

    testWidgets('shows purge error banner with retry tap', (tester) async {
      final cubit = _RetryPurgeMyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit);

      expect(
        find.text(l10n.myDataPurgeErrorGeneric),
        findsOneWidget,
      );

      await tester.tap(
        find.text(l10n.myDataPurgeErrorGeneric),
      );
      await tester.pump();

      expect(cubit.purgeAttempts, 1);
    });

    testWidgets('delete anyway confirms purge while export from dialog is in flight', (
      tester,
    ) async {
      final cubit = _DialogPurgeFlowMyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit: cubit, disableAnimations: true);

      await tester.scrollUntilVisible(
        find.text(l10n.myDataDeleteAllLocalData),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.myDataDeleteAllLocalData));
      await tester.pump();
      expect(find.text(l10n.myDataPurgeExportFirst), findsOneWidget);

      await tester.tap(find.text(l10n.myDataPurgeExportFirst));
      await tester.pump();
      expect(cubit.state.isExporting, isTrue);

      await tester.tap(find.text(l10n.myDataPurgeDeleteAnyway));
      await tester.pump();
      await tester.pump();

      expect(cubit.confirmedPurgeWhileExporting, isTrue);
      expect(find.text(l10n.myDataPurgeSuccess), findsOneWidget);
      expect(cubit.state.purgeSuccessPending, isFalse);
    });
  });
}

class _RetryImportMyDataCubit extends _SeededMyDataCubit {
  _RetryImportMyDataCubit({
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           importError: MyDataImportError.validation,
           importValidationDetail: 'Row 1: expected 10 columns',
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
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           exportError: MyDataExportError.generic,
         ),
       );

  int exportAttempts = 0;

  @override
  Future<void> exportAndShare() async {
    exportAttempts++;
  }
}

class _DialogPurgeFlowMyDataCubit extends _SeededMyDataCubit {
  _DialogPurgeFlowMyDataCubit({
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.databasePath,
  }) : super(seededState: _readyState());

  var confirmedPurgeWhileExporting = false;

  @override
  Future<void> exportAndShare() async {
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
    required super.stepAggregation,
    required super.csvService,
    required super.stepIngestion,
    required super.userSettings,
    required super.userHealthMetrics,
    required super.clock,
    required super.databasePath,
  }) : super(
         seededState: MyDataState(
           status: MyDataStatus.ready,
           sampleCount: 10,
           fileSizeBytes: 1024,
           backgroundStatus: BackgroundCollectionStatus.healthy,
           isIos: false,
           purgeError: MyDataPurgeError.generic,
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
