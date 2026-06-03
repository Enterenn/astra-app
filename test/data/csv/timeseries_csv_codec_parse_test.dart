import 'package:astra_app/data/csv/import_validation_exception.dart';
import 'package:astra_app/data/csv/timeseries_csv_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeseriesCsvCodec parse', () {
    test('parseHeaderRow accepts exact OW header', () {
      expect(
        () => TimeseriesCsvCodec.parseHeaderRow(TimeseriesCsvCodec.headerRow),
        returnsNormally,
      );
    });

    test('parseHeaderRow rejects wrong column order', () {
      expect(
        () => TimeseriesCsvCodec.parseHeaderRow(
          'start_time,id,end_time,type,value,unit,resolution,provider,device_id,zone_offset',
        ),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('parseDataRow round-trips serializeRow output', () {
      final sample = _sample();
      final row = TimeseriesCsvCodec.serializeRow(sample);
      final parsed = TimeseriesCsvCodec.parseDataRow(row, rowNumber: 1);

      expect(parsed.id, sample.id);
      expect(parsed.value, sample.value);
      expect(parsed.startTimeUtc, sample.startTimeUtc);
      expect(parsed.zoneOffset, sample.zoneOffset);
    });

    test('parseDataRow accepts integer steps value', () {
      final parsed = TimeseriesCsvCodec.parseDataRow(
        '00000000-0000-4000-8000-000000000001,'
        '2026-05-22T14:30:00Z,'
        '2026-05-22T14:35:00Z,'
        'steps,42,count,5min,internal_phone,smartphone,+02:00',
        rowNumber: 1,
      );
      expect(parsed.value, 42);
    });

    test('parseDataRow rejects non-integer steps value', () {
      expect(
        () => TimeseriesCsvCodec.parseDataRow(
          '00000000-0000-4000-8000-000000000001,'
          '2026-05-22T14:30:00Z,'
          '2026-05-22T14:35:00Z,'
          'steps,42.5,count,5min,internal_phone,smartphone,+02:00',
          rowNumber: 3,
        ),
        throwsA(
          predicate<ImportValidationException>(
            (e) => e.message.contains('Row 3'),
          ),
        ),
      );
    });

    test('parseDataRow RFC 4180 unescapes quoted comma fields', () {
      final sample = _sample(deviceId: 'phone,test');
      final row = TimeseriesCsvCodec.serializeRow(sample);
      final parsed = TimeseriesCsvCodec.parseDataRow(row, rowNumber: 1);
      expect(parsed.deviceId, 'phone,test');
    });

    test('parseCsvFields handles carriage returns inside quoted field', () {
      final fields = TimeseriesCsvCodec.parseCsvFields('"line\rend"');
      expect(fields.single, 'line\rend');
    });

    test('parseHeaderRow handles CRLF-stripped header line', () {
      expect(
        () => TimeseriesCsvCodec.parseHeaderRow(
          '${TimeseriesCsvCodec.headerRow}\r',
        ),
        returnsNormally,
      );
    });

    test('parseDataRow rejects non-steps type', () {
      expect(
        () => TimeseriesCsvCodec.parseDataRow(
          '00000000-0000-4000-8000-000000000001,'
          '2026-05-22T14:30:00Z,'
          '2026-05-22T14:35:00Z,'
          'heart_rate,42,count,5min,internal_phone,smartphone,+02:00',
          rowNumber: 2,
        ),
        throwsA(
          predicate<ImportValidationException>(
            (e) => e.message.contains('Row 2'),
          ),
        ),
      );
    });
  });
}

TimeseriesSampleModel _sample({String deviceId = kSmartphoneDeviceId}) {
  return TimeseriesSampleModel(
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    startTimeUtc: DateTime.utc(2026, 5, 22, 14, 30),
    endTimeUtc: DateTime.utc(2026, 5, 22, 14, 35),
    type: kStepSampleType,
    value: 132,
    unit: kStepSampleUnit,
    resolution: kFiveMinuteResolution,
    provider: kInternalPhoneProvider,
    deviceId: deviceId,
    zoneOffset: '+02:00',
  );
}
