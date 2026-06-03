import 'package:astra_app/data/csv/timeseries_csv_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeseriesCsvCodec', () {
    test('header row uses exact OW column order', () {
      expect(
        TimeseriesCsvCodec.headerRow,
        'id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset',
      );
    });

    test('serializeRow emits integer string for steps value', () {
      final row = TimeseriesCsvCodec.serializeRow(_sample(value: 132));

      expect(row.split(','), hasLength(10));
      expect(row.split(',')[4], '132');
      expect(row, isNot(contains('.0')));
    });

    test('serializeRow preserves DB map strings unchanged', () {
      final sample = _sample(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        startTimeUtc: DateTime.utc(2026, 5, 22, 14, 30),
        endTimeUtc: DateTime.utc(2026, 5, 22, 14, 35),
        zoneOffset: '+02:00',
      );

      final row = TimeseriesCsvCodec.serializeRow(sample);

      expect(
        row,
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890,'
        '2026-05-22T14:30:00Z,'
        '2026-05-22T14:35:00Z,'
        'steps,132,count,5min,internal_phone,smartphone,+02:00',
      );
    });

    test('serializeRow RFC 4180 escapes comma-containing fields', () {
      final row = TimeseriesCsvCodec.serializeRow(
        _sample(deviceId: 'phone,test'),
      );

      expect(row, contains('"phone,test"'));
    });

    test('serializeRow RFC 4180 escapes quotes and newlines', () {
      final row = TimeseriesCsvCodec.serializeRow(
        _sample(deviceId: 'a"b\nc'),
      );

      expect(row, contains('"a""b\nc"'));
    });

    test('serializeRow RFC 4180 escapes carriage returns', () {
      final row = TimeseriesCsvCodec.serializeRow(
        _sample(deviceId: 'line\rend'),
      );

      expect(row, contains('"line\rend"'));
    });
  });
}

TimeseriesSampleModel _sample({
  String id = '00000000-0000-4000-8000-000000000001',
  DateTime? startTimeUtc,
  DateTime? endTimeUtc,
  num value = 132,
  String zoneOffset = '+02:00',
  String deviceId = kSmartphoneDeviceId,
}) {
  final start = startTimeUtc ?? DateTime.utc(2026, 5, 22, 14, 30);
  final end = endTimeUtc ?? DateTime.utc(2026, 5, 22, 14, 35);
  return TimeseriesSampleModel(
    id: id,
    startTimeUtc: start,
    endTimeUtc: end,
    type: kStepSampleType,
    value: value,
    unit: kStepSampleUnit,
    resolution: kFiveMinuteResolution,
    provider: kInternalPhoneProvider,
    deviceId: deviceId,
    zoneOffset: zoneOffset,
  );
}
