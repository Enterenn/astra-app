import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/models/step_reading.dart';
import '../../data/repositories/step_repository.dart';
import '../time/time_provider.dart';

class BackgroundCollector {
  BackgroundCollector({
    required List<DataIngestionSource> sources,
    required this.normalizer,
    required this.repository,
    required this.clock,
    this.onIngestionComplete,
    this.sourceTimeout = const Duration(seconds: 2),
  }) : _sources = List.unmodifiable(sources);

  final List<DataIngestionSource> _sources;
  final StepNormalizer normalizer;
  final StepRepository repository;

  /// Injected for consistency with the ingestion pipeline; do not use DateTime.now().
  final TimeProvider clock;

  /// UI isolate hook only. WorkManager isolates should leave this null.
  final VoidCallback? onIngestionComplete;

  final Duration sourceTimeout;

  Future<int> collectOnce({int maxReadingsPerSource = 50}) async {
    var upsertedCount = 0;

    for (final source in _sources) {
      try {
        final buckets = await normalizer.normalize(
          _TimeoutBoundedSource(source, timeout: sourceTimeout),
          maxReadings: maxReadingsPerSource,
        );

        for (final bucket in buckets) {
          await repository.upsertIngestionBucket(bucket);
          upsertedCount += 1;
        }
      } catch (error, stackTrace) {
        debugPrint(
          'BackgroundCollector failed for ${source.providerId}/${source.deviceId}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (upsertedCount > 0) {
      onIngestionComplete?.call();
    }

    return upsertedCount;
  }
}

class _TimeoutBoundedSource implements DataIngestionSource {
  const _TimeoutBoundedSource(this._delegate, {required this.timeout});

  final DataIngestionSource _delegate;
  final Duration timeout;

  @override
  String get providerId => _delegate.providerId;

  @override
  String get deviceId => _delegate.deviceId;

  @override
  Stream<StepReading> watchStepReadings() {
    return _delegate.watchStepReadings().timeout(
      timeout,
      onTimeout: (sink) {
        sink.close();
      },
    );
  }
}
