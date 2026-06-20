import 'dart:async';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector.dart';
import 'package:astra_app/core/services/live_step_monitor.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/monitor_drain_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/ingestion_baseline_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MonitorDrainSource', () {
    late Database db;
    late StepTestRepos stepRepos;
    late IngestionBaselineRepository baselineRepository;
    late FakeTimeProvider clock;
    late StreamController<PhoneStepEvent> phoneEvents;
    late LiveStepMonitor monitor;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 8),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
      baselineRepository = IngestionBaselineRepository(db);
      phoneEvents = StreamController<PhoneStepEvent>.broadcast();
      monitor = LiveStepMonitor(
        stepAggregation: stepRepos.aggregation,
        baselineRepository: baselineRepository,
        clock: clock,
        stepEventStreamFactory: () => phoneEvents.stream,
        emitThrottle: Duration.zero,
      );
    });

    tearDown(() async {
      await phoneEvents.close();
      await monitor.stop();
      await db.close();
    });

    test('drains monitor buffer while monitor is running', () async {
      await monitor.start();
      phoneEvents.add(
        PhoneStepEvent(steps: 100, timeStamp: DateTime.utc(2026, 6, 2, 8)),
      );
      phoneEvents.add(
        PhoneStepEvent(steps: 200, timeStamp: DateTime.utc(2026, 6, 2, 8, 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final source = MonitorDrainSource(monitor);
      final readings = await source.watchStepReadings().toList();

      expect(readings, hasLength(2));
      expect(readings.last.cumulativeSteps, 200);
      expect(monitor.drainReadingsForCollection(), isEmpty);
    });

    test('reads phone pedometer when monitor is stopped', () async {
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 2559,
      );

      final fallbackEvents = StreamController<PhoneStepEvent>();
      final source = MonitorDrainSource(
        monitor,
        phoneFallback: PhonePedometerSource(
          stepEventStreamFactory: () => fallbackEvents.stream,
        ),
      );

      final collectFuture = source.watchStepReadings().first;
      fallbackEvents.add(
        PhoneStepEvent(steps: 2680, timeStamp: DateTime.utc(2026, 6, 2, 8, 5)),
      );

      final reading = await collectFuture;
      expect(reading.cumulativeSteps, 2680);
      await fallbackEvents.close();
    });

    test('collectOnce ingests pocket-walk delta after monitor stop', () async {
      await baselineRepository.setBaseline(
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        cumulative: 2559,
      );
      await stepRepos.ingestion.upsertIngestionBucket(
        NormalizedStepBucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 8),
          endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
          value: 2559,
          provider: kInternalPhoneProvider,
          deviceId: kSmartphoneDeviceId,
          zoneOffset: '+02:00',
        ),
      );
      await monitor.stop();

      final fallbackEvents = StreamController<PhoneStepEvent>();
      final collector = BackgroundCollector(
        sources: [
          MonitorDrainSource(
            monitor,
            phoneFallback: PhonePedometerSource(
              stepEventStreamFactory: () => fallbackEvents.stream,
            ),
          ),
        ],
        normalizer: StepNormalizer(clock: clock),
        repository: stepRepos.ingestion,
        stepAggregation: stepRepos.aggregation,
        baselineRepository: baselineRepository,
        sourceTimeout: const Duration(milliseconds: 50),
      );

      final collectFuture = collector.collectOnce();
      fallbackEvents.add(
        PhoneStepEvent(steps: 2680, timeStamp: DateTime.utc(2026, 6, 2, 8, 5)),
      );

      final upserted = await collectFuture;
      expect(upserted, greaterThan(0));
      expect(await stepRepos.aggregation.getTodaySteps(), 2680);
      await fallbackEvents.close();
    });
  });
}
