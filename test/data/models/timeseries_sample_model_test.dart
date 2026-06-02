import 'package:astra_app/core/time/timestamp_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimestampCodec', () {
    test('formats and parses ISO 8601 UTC timestamps with a Z suffix', () {
      final timestamp = DateTime.utc(2026, 6, 2, 10);

      final encoded = TimestampCodec.formatUtc(timestamp);

      expect(encoded, '2026-06-02T10:00:00Z');
      expect(TimestampCodec.parseUtc(encoded), DateTime.utc(2026, 6, 2, 10));
    });

    test('rejects non-UTC storage strings', () {
      expect(
        () => TimestampCodec.parseUtc('2026-06-02T10:00:00+02:00'),
        throwsFormatException,
      );
    });
  });

  group('TimeseriesSampleModel', () {
    test('maps a normalized step bucket to a canonical database row', () {
      final bucket = NormalizedStepBucket(
        startTimeUtc: DateTime.utc(2026, 6, 2, 8),
        endTimeUtc: DateTime.utc(2026, 6, 2, 8, 5),
        value: 42,
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        zoneOffset: '+02:00',
      );

      final model = TimeseriesSampleModel.fromNormalizedBucket(
        bucket: bucket,
        id: '00000000-0000-4000-8000-000000000001',
      );

      expect(model.toMap(), {
        'id': '00000000-0000-4000-8000-000000000001',
        'start_time': '2026-06-02T08:00:00Z',
        'end_time': '2026-06-02T08:05:00Z',
        'type': kStepSampleType,
        'value': 42,
        'unit': kStepSampleUnit,
        'resolution': kFiveMinuteResolution,
        'provider': kInternalPhoneProvider,
        'device_id': kSmartphoneDeviceId,
        'zone_offset': '+02:00',
      });
    });

    test('round-trips a database row without changing stored timestamps', () {
      final row = {
        'id': '00000000-0000-4000-8000-000000000002',
        'start_time': '2026-06-02T08:00:00Z',
        'end_time': '2026-06-02T08:05:00Z',
        'type': kStepSampleType,
        'value': 12,
        'unit': kStepSampleUnit,
        'resolution': kFiveMinuteResolution,
        'provider': kInternalPhoneProvider,
        'device_id': kSmartphoneDeviceId,
        'zone_offset': '-05:00',
      };

      final model = TimeseriesSampleModel.fromMap(row);

      expect(model.startTimeUtc, DateTime.utc(2026, 6, 2, 8));
      expect(model.endTimeUtc, DateTime.utc(2026, 6, 2, 8, 5));
      expect(model.value, 12);
      expect(model.toMap(), row);
    });
  });
}
