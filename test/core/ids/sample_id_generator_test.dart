@Tags(['slow'])
library;

import 'package:astra_app/core/ids/sample_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../time/fake_time_provider.dart';

void main() {
  group('SampleIdGenerator', () {
    test('nextId returns base36 microsecond timestamp on first call', () {
      final fixed = DateTime.utc(2026, 6, 18, 12, 0, 0, 123, 456);
      final clock = FakeTimeProvider(
        fixedNowUtc: fixed,
        zoneOffset: Duration.zero,
      );
      final generator = SampleIdGenerator(clock);

      expect(
        generator.nextId(),
        fixed.microsecondsSinceEpoch.toRadixString(36),
      );
    });

    test('nextId appends sequence suffix when same microsecond is reused', () {
      final fixed = DateTime.utc(2026, 6, 18, 12, 0, 0);
      final clock = FakeTimeProvider(
        fixedNowUtc: fixed,
        zoneOffset: Duration.zero,
      );
      final generator = SampleIdGenerator(clock);
      final base = fixed.microsecondsSinceEpoch.toRadixString(36);

      final first = generator.nextId();
      final second = generator.nextId();
      final third = generator.nextId();

      expect(first, base);
      expect(second, '$base-1');
      expect(third, '$base-2');
      expect({first, second, third}, hasLength(3));
    });

    test('deterministicFromStartUtc is stable and normalizes to UTC', () {
      final start = DateTime.utc(2026, 1, 15, 8, 30);

      expect(
        SampleIdGenerator.deterministicFromStartUtc(start),
        start.microsecondsSinceEpoch.toRadixString(36),
      );
      expect(
        SampleIdGenerator.deterministicFromStartUtc(
          DateTime(2026, 1, 15, 9, 30),
        ),
        start.microsecondsSinceEpoch.toRadixString(36),
      );
    });

    test('deterministicFromMergedBucket appends resolution to avoid tier PK clash', () {
      final start = DateTime.utc(2026, 6, 1, 0, 0);

      expect(
        SampleIdGenerator.deterministicFromMergedBucket(
          startTimeUtc: start,
          resolution: '1hour',
        ),
        '${start.microsecondsSinceEpoch.toRadixString(36)}-1hour',
      );
      expect(
        SampleIdGenerator.deterministicFromMergedBucket(
          startTimeUtc: start,
          resolution: '1d',
        ),
        isNot(
          SampleIdGenerator.deterministicFromMergedBucket(
            startTimeUtc: start,
            resolution: '1hour',
          ),
        ),
      );
    });

    test('deterministicFromIngestionBucket differs for same start across providers', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);

      expect(
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'internal_phone',
          deviceId: 'smartphone',
          type: 'steps',
          resolution: '5min',
        ),
        isNot(
          SampleIdGenerator.deterministicFromIngestionBucket(
            startTimeUtc: start,
            provider: 'adp_ble',
            deviceId: 'ring',
            type: 'steps',
            resolution: '5min',
          ),
        ),
      );
    });

    test('deterministicFromIngestionBucket keeps legacy id for steps and 5min defaults', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);
      const legacyIdentity = 'internalphonesmartphone';
      final expected =
          '${start.microsecondsSinceEpoch.toRadixString(36)}-$legacyIdentity';

      expect(
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'internal_phone',
          deviceId: 'smartphone',
          type: 'steps',
          resolution: '5min',
        ),
        expected,
      );
    });

    test('deterministicFromIngestionBucket keeps legacy id when type or resolution casing varies', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);
      const legacyIdentity = 'internalphonesmartphone';
      final expected =
          '${start.microsecondsSinceEpoch.toRadixString(36)}-$legacyIdentity';

      expect(
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'internal_phone',
          deviceId: 'smartphone',
          type: 'Steps',
          resolution: '5Min',
        ),
        expected,
      );
    });

    test('deterministicFromIngestionBucket appends type and resolution suffix for non-default buckets', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);
      const identity = 'internalphonesmartphone';
      final expected =
          '${start.microsecondsSinceEpoch.toRadixString(36)}-$identity-heart_rate-5min';

      expect(
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'internal_phone',
          deviceId: 'smartphone',
          type: 'heart_rate',
          resolution: '5min',
        ),
        expected,
      );
    });

    test('deterministicFromIngestionBucket differs when type or resolution changes', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);
      const provider = 'internal_phone';
      const deviceId = 'smartphone';

      final stepsFiveMin = SampleIdGenerator.deterministicFromIngestionBucket(
        startTimeUtc: start,
        provider: provider,
        deviceId: deviceId,
        type: 'steps',
        resolution: '5min',
      );
      final heartRateFiveMin = SampleIdGenerator.deterministicFromIngestionBucket(
        startTimeUtc: start,
        provider: provider,
        deviceId: deviceId,
        type: 'heart_rate',
        resolution: '5min',
      );
      final stepsHourly = SampleIdGenerator.deterministicFromIngestionBucket(
        startTimeUtc: start,
        provider: provider,
        deviceId: deviceId,
        type: 'steps',
        resolution: '1hour',
      );

      expect(heartRateFiveMin, isNot(stepsFiveMin));
      expect(stepsHourly, isNot(stepsFiveMin));
      expect(stepsHourly, isNot(heartRateFiveMin));
    });

    test('deterministicFromIngestionBucket normalizes provider and device case', () {
      final start = DateTime.utc(2026, 6, 1, 22, 30);

      expect(
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'ProviderA',
          deviceId: 'DeviceX',
          type: 'steps',
          resolution: '5min',
        ),
        SampleIdGenerator.deterministicFromIngestionBucket(
          startTimeUtc: start,
          provider: 'providera',
          deviceId: 'devicex',
          type: 'steps',
          resolution: '5min',
        ),
      );
    });
  });
}
