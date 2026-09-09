import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/models/step_reading.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step/step_aggregation_repository.dart';
import '../../data/repositories/step/step_ingestion_repository.dart';
import '../../data/repositories/user_health_metrics_repository.dart';
import '../../data/repositories/user_settings_repository.dart';
import '../constants/preference_keys.dart';
import '../debug/field_diagnostic_log.dart';
import '../time/local_day_formatter.dart';
import '../time/time_provider.dart';
import 'ingestion_collection_lock.dart';
import 'notification_service.dart';

/// Orchestrates one background ingest cycle: sources → normalize → SQLite upsert.
///
/// Optionally evaluates goal notifications when the app is not in the foreground.
class BackgroundCollector {
  BackgroundCollector({
    required List<DataIngestionSource> sources,
    required this.normalizer,
    required this.repository,
    required this.stepAggregation,
    required this.baselineRepository,
    this.userSettings,
    this.userHealthMetrics,
    this.clock,
    this.notificationService,
    this.notificationPermissionGranted,
    this.isUserFacingAppActive,
    this.sourceTimeout = const Duration(seconds: 2),
    this.maxCollectionDuration = const Duration(seconds: 25),
  }) : _sources = List.unmodifiable(sources);

  final List<DataIngestionSource> _sources;
  final StepNormalizer normalizer;
  final StepIngestionRepository repository;
  final StepAggregationRepository stepAggregation;
  final IngestionBaselineRepository baselineRepository;
  final UserSettingsRepository? userSettings;
  final UserHealthMetricsRepository? userHealthMetrics;
  final TimeProvider? clock;
  final NotificationService? notificationService;
  final Future<bool> Function()? notificationPermissionGranted;

  /// When `true`, the user is on the app — skip goal notification (celebration only).
  final bool Function()? isUserFacingAppActive;

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
    Duration? sourceTimeout,
    String? fieldLogOrigin,
  }) async {
    if (_collectInFlight) {
      if (fieldLogOrigin != null) {
        fieldDiagnosticLog(
          fieldLogOrigin,
          'collection SKIPPED reason=in_flight',
        );
      }
      return 0;
    }
    _collectInFlight = true;
    try {
      if (await IngestionCollectionLock.isHeld(
        repository.databaseSession,
        kDatabaseMaintenanceLockKey,
        clock: clock,
      )) {
        if (fieldLogOrigin != null) {
          fieldDiagnosticLog(
            fieldLogOrigin,
            'collection SKIPPED reason=maintenance_lock',
          );
        }
        return 0;
      }

      final lock = IngestionCollectionLock(repository.databaseSession, clock: clock);
      if (!await lock.tryAcquire()) {
        if (fieldLogOrigin != null) {
          fieldDiagnosticLog(
            fieldLogOrigin,
            'collection SKIPPED reason=lock_busy',
          );
        }
        return 0;
      }
      try {
        return await _collectOnce(
          maxReadingsPerSource: maxReadingsPerSource,
          enableGoalNotification: enableGoalNotification,
          sourceTimeout: sourceTimeout ?? this.sourceTimeout,
          fieldLogOrigin: fieldLogOrigin,
        );
      } finally {
        await lock.release();
      }
    } finally {
      _collectInFlight = false;
    }
  }

  Future<int> _collectOnce({
    required int maxReadingsPerSource,
    required bool enableGoalNotification,
    required Duration sourceTimeout,
    String? fieldLogOrigin,
  }) async {
    var upsertedCount = 0;

    for (final source in _sources) {
      try {
        final snapshot = await baselineRepository.getBaselineSnapshot(
          provider: source.providerId,
          deviceId: source.deviceId,
        );
        final lastIngestionUtc = snapshot?.recordedAtUtc ??
            await repository.getLastIngestionUtcForSource(
              provider: source.providerId,
              deviceId: source.deviceId,
            );
        final result = await normalizer.normalize(
          _TimeoutBoundedSource(
            source,
            timeout: sourceTimeout,
            maxCollectionDuration: maxCollectionDuration,
            clock: clock,
          ),
          maxReadings: maxReadingsPerSource,
          initialBaseline: snapshot?.cumulative,
          lastIngestionUtc: lastIngestionUtc,
        );

        final terminalBaseline = result.terminalBaseline;
        if (result.buckets.isNotEmpty || terminalBaseline != null) {
          final bucketCount = result.buckets.length;
          await repository.databaseSession.withRetry((db) async {
            await db.transaction((txn) async {
              for (final bucket in result.buckets) {
                await repository.upsertIngestionBucket(bucket, txn: txn);
              }
              if (terminalBaseline != null) {
                await baselineRepository.setBaseline(
                  provider: source.providerId,
                  deviceId: source.deviceId,
                  cumulative: terminalBaseline,
                  recordedAtUtc: clock?.nowUtc(),
                  txn: txn,
                );
              }
            });
          });
          upsertedCount += bucketCount;
        }
      } catch (error, stackTrace) {
        if (fieldLogOrigin != null) {
          fieldDiagnosticLog(
            fieldLogOrigin,
            'source FAIL',
            details: {
              'provider': source.providerId,
              'device': source.deviceId,
              'error': error,
            },
          );
        }
        debugPrint(
          'BackgroundCollector failed for ${source.providerId}/${source.deviceId}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (enableGoalNotification) {
      await maybeNotifyGoalReachedIfGoalMet();
    }

    if (upsertedCount > 0) {
      _onIngestionComplete?.call();
    }

    if (fieldLogOrigin != null) {
      fieldDiagnosticLog(
        fieldLogOrigin,
        upsertedCount > 0 ? 'collection OK' : 'collection OK no_buckets',
        details: {'upserted': upsertedCount},
      );
    }

    return upsertedCount;
  }

  /// Evaluates goal + prefs and may fire the local notification (FR-25).
  ///
  /// Only when the user is **not** on the app (`isUserFacingAppActive` false).
  /// Independent from in-app celebration dedup.
  Future<void> maybeNotifyGoalReachedIfGoalMet() async {
    final settings = userSettings;
    final health = userHealthMetrics;
    final notifications = notificationService;
    final time = clock;
    final permissionCheck = notificationPermissionGranted;
    if (settings == null ||
        health == null ||
        notifications == null ||
        time == null ||
        permissionCheck == null) {
      return;
    }

    if (isUserFacingAppActive?.call() ?? false) {
      return;
    }

    if (!await settings.getGoalNotificationsEnabled()) {
      return;
    }

    if (!await permissionCheck()) {
      fieldDiagnosticLog(
        'notify',
        'goal SKIPPED reason=no_notification_permission',
        minInterval: const Duration(hours: 1),
      );
      return;
    }

    final todayIso = formatLocalDayIso(time.snapshot());

    final goal = await health.getGoalForLocalDay(todayIso);
    if (goal <= 0) {
      return;
    }

    final steps = await stepAggregation.getTodaySteps();
    if (steps < goal) {
      return;
    }

    if (!await settings.tryClaimGoalNotificationShownDate(todayIso)) {
      return;
    }

    final shown = await notifications.showGoalReached(stepsToday: steps);
    if (!shown) {
      await settings.clearGoalNotificationShownDateIfMatches(todayIso);
    }
  }
}

class _TimeoutBoundedSource implements DataIngestionSource {
  _TimeoutBoundedSource(
    this._delegate, {
    required this.timeout,
    required this.maxCollectionDuration,
    this._clock,
  });

  final DataIngestionSource _delegate;
  final Duration timeout;
  final Duration maxCollectionDuration;
  final TimeProvider? _clock;

  DateTime _nowUtc() => (_clock?.nowUtc() ?? DateTime.now().toUtc());

  @override
  String get providerId => _delegate.providerId;

  @override
  String get deviceId => _delegate.deviceId;

  @override
  Stream<StepReading> watchStepReadings() async* {
    final deadline = _nowUtc().add(maxCollectionDuration);
    await for (final reading in _delegate.watchStepReadings().timeout(
      timeout,
      onTimeout: (sink) {
        sink.close();
      },
    )) {
      if (_nowUtc().isAfter(deadline)) {
        break;
      }
      yield reading;
    }
  }
}
