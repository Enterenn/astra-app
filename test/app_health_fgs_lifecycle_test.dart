import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/core/services/health_foreground_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'core/time/fake_time_provider.dart';
import 'helpers/sqflite_test_helper.dart';

class _RecordingHealthFgs extends HealthForegroundServiceCoordinator {
  _RecordingHealthFgs({required this.calls})
    : super(
        channel: const MethodChannel('test/health_fgs'),
        activityPermissionGranted: () async => true,
        isAndroidPlatform: () => true,
      );

  final List<String> calls;

  @override
  Future<void> startHealthCollectionService() async {
    calls.add('start');
  }

  @override
  Future<void> stopHealthCollectionService() async {
    calls.add('stop');
  }

  @override
  Future<void> setUiActive(bool active) async {
    calls.add('uiActive:$active');
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  testWidgets('starts FGS on pause and stops on resume', (tester) async {
    final fgsCalls = <String>[];
    final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(db.close);
    final userPreferences = UserPreferencesRepository(db);
    await userPreferences.setOnboardingComplete(true);
    final clock = FakeTimeProvider(
      fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
      zoneOffset: const Duration(hours: 2),
    );
    final healthFgs = _RecordingHealthFgs(calls: fgsCalls);
    final deps = await AppDependencies.test(
      db: db,
      userPreferences: userPreferences,
      timeProvider: clock,
      healthForegroundCoordinator: healthFgs,
    );

    await tester.pumpWidget(
      AstraApp(
        deps: deps,
        createTodayCubit: (dependencies) => TodayCubit(
          stepRepository: dependencies.stepRepository,
          userPreferences: dependencies.userPreferences,
          clock: dependencies.timeProvider,
          activityPermissionGranted: () async => true,
        ),
        createHistoryCubit: (dependencies) => HistoryCubit(
          stepRepository: dependencies.stepRepository,
          userPreferences: dependencies.userPreferences,
        ),
        enablePeriodicPersist: false,
        enableLiveStepPipeline: false,
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fgsCalls, contains('uiActive:false'));
    expect(fgsCalls, contains('start'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fgsCalls, contains('stop'));
    expect(fgsCalls.last, 'uiActive:true');
  });
}
