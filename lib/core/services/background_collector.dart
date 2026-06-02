import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/models/step_reading.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../time/local_day_formatter.dart';
import '../time/time_provider.dart';
import 'notification_service.dart';

class BackgroundCollector {
  BackgroundCollector({
    required List<DataIngestionSource> sources,
    required this.normalizer,
    required this.repository,
    required this.baselineRepository,
    this.userPreferences,
    this.clock,
    this.notificationService,
    this.notificationPermissionGranted,
    this.sourceTimeout = const Duration(seconds: 2),
    this.maxCollectionDuration = const Duration(seconds: 25),
  }) : _sources = List.unmodifiable(sources);

  final List<DataIngestionSource> _sources;
  final StepNormalizer normalizer;
  final StepRepository repository;
  final IngestionBaselineRepository baselineRepository;
  final UserPreferencesRepository? userPreferences;
  final TimeProvider? clock;
  final NotificationService? notificationService;
  final Future<bool> Function()? notificationPermissionGranted;

  /// UI isolate hook only. WorkManager isolates should leave this null.
  VoidCallback? _onIngestionComplete;

  /// Registers a callback invoked after successful bucket upserts (UI isolate).
  void registerOnIngestionComplete(VoidCallback? callback) {
    _onIngestionComplete = callback;
  }

  final Duration sourceTimeout;
  final Duration maxCollectionDuration;

  bool _collectInFlight = false;

  Future<int> collectOnce({
    int maxReadingsPerSource = 50,
    bool enableGoalNotification = false,
  }) async {
    if (_collectInFlight) {
      return 0;
    }
    _collectInFlight = true;
    try {
      return await _collectOnce(
        maxReadingsPerSource: maxReadingsPerSource,
        enableGoalNotification: enableGoalNotification,
      );
    } finally {
      _collectInFlight = false;
    }
  }

  Future<int> _collectOnce({
    required int maxReadingsPerSource,
    required bool enableGoalNotification,
  }) async {
    var upsertedCount = 0;

    for (final source in _sources) {
      try {
        final initialBaseline = await baselineRepository.getBaseline(
          provider: source.providerId,
          deviceId: source.deviceId,
        );
        final result = await normalizer.normalize(
          _TimeoutBoundedSource(
            source,
            timeout: sourceTimeout,
            maxCollectionDuration: maxCollectionDuration,
          ),
          maxReadings: maxReadingsPerSource,
          initialBaseline: initialBaseline,
        );

        for (final bucket in result.buckets) {
          await repository.upsertIngestionBucket(bucket);
          upsertedCount += 1;
        }

        final terminalBaseline = result.terminalBaseline;
        if (terminalBaseline != null) {
          await baselineRepository.setBaseline(
            provider: source.providerId,
            deviceId: source.deviceId,
            cumulative: terminalBaseline,
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'BackgroundCollector failed for ${source.providerId}/${source.deviceId}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (enableGoalNotification) {
      await _maybeNotifyGoalReached();
    }

    if (upsertedCount > 0) {
      _onIngestionComplete?.call();
    }

    return upsertedCount;
  }

  Future<void> _maybeNotifyGoalReached() async {
    final prefs = userPreferences;
    final notifications = notificationService;
    final time = clock;
    final permissionCheck = notificationPermissionGranted;
    if (prefs == null ||
        notifications == null ||
        time == null ||
        permissionCheck == null) {
      return;
    }

    if (!await permissionCheck()) {
      return;
    }

    final todayIso = formatLocalDayIso(time.snapshot());

    final goal = await prefs.getDailyStepGoal();
    if (goal <= 0) {
      return;
    }

    final steps = await repository.getTodaySteps();
    if (steps < goal) {
      return;
    }

    if (!await prefs.tryClaimCelebrationShownDate(todayIso)) {
      return;
    }

    await notifications.showGoalReached(stepsToday: steps);
  }
}

class _TimeoutBoundedSource implements DataIngestionSource {
  const _TimeoutBoundedSource(
    this._delegate, {
    required this.timeout,
    required this.maxCollectionDuration,
  });

  final DataIngestionSource _delegate;
  final Duration timeout;
  final Duration maxCollectionDuration;

  @override
  String get providerId => _delegate.providerId;

  @override
  String get deviceId => _delegate.deviceId;

  @override
  Stream<StepReading> watchStepReadings() async* {
    final deadline = DateTime.now().add(maxCollectionDuration);
    await for (final reading in _delegate.watchStepReadings().timeout(
      timeout,
      onTimeout: (sink) {
        sink.close();
      },
    )) {
      if (DateTime.now().isAfter(deadline)) {
        break;
      }
      yield reading;
    }
  }
}
