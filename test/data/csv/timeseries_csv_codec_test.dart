import 'dart:io';

import 'package:astra_app/data/csv/import_validation_exception.dart';
import 'package:astra_app/data/csv/timeseries_csv_codec.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeseriesCsvCodec serialize', () {
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

    test('serializeRow RFC 4180 escapes special characters', () {
      expect(
        TimeseriesCsvCodec.serializeRow(_sample(deviceId: 'phone,test')),
        contains('"phone,test"'),
      );
      expect(
        TimeseriesCsvCodec.serializeRow(_sample(deviceId: 'a"b\nc')),
        contains('"a""b\nc"'),
      );
      expect(
        TimeseriesCsvCodec.serializeRow(_sample(deviceId: 'line\rend')),
        contains('"line\rend"'),
      );
    });
  });

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

    test('parseHeaderRow accepts UTF-8 BOM prefix', () {
      expect(
        () => TimeseriesCsvCodec.parseHeaderRow(
          '\uFEFF${TimeseriesCsvCodec.headerRow}',
        ),
        returnsNormally,
      );
    });

    test('parseImportFile round-trips row with quoted newline in field', () async {
      final sample = _sample(deviceId: 'phone\ntest');
      final file = await _writeTempCsv([
        TimeseriesCsvCodec.headerRow,
        TimeseriesCsvCodec.serializeRow(sample),
      ]);

      final parsed = await TimeseriesCsvCodec.parseImportFile(file.path);
      expect(parsed, hasLength(1));
      expect(parsed.single.deviceId, 'phone\ntest');

      await file.delete();
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

    test('parseDataRow accepts legacy UUID v4 id', () {
      final parsed = TimeseriesCsvCodec.parseDataRow(
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890,'
        '2026-05-22T14:30:00Z,'
        '2026-05-22T14:35:00Z,'
        'steps,42,count,5min,internal_phone,smartphone,+02:00',
        rowNumber: 1,
      );

      expect(parsed.id, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
    });

    test('parseDataRow accepts base36 timestamp id', () {
      final parsed = TimeseriesCsvCodec.parseDataRow(
        'l7x3k2m-1,'
        '2026-05-22T14:30:00Z,'
        '2026-05-22T14:35:00Z,'
        'steps,42,count,5min,internal_phone,smartphone,+02:00',
        rowNumber: 1,
      );

      expect(parsed.id, 'l7x3k2m-1');
    });

    test('parseDataRow rejects garbage id', () {
      expect(
        () => TimeseriesCsvCodec.parseDataRow(
          'not-a-valid-id!,'
          '2026-05-22T14:30:00Z,'
          '2026-05-22T14:35:00Z,'
          'steps,42,count,5min,internal_phone,smartphone,+02:00',
          rowNumber: 5,
        ),
        throwsA(
          predicate<ImportValidationException>(
            (e) => e.message.contains('Row 5: id must be a valid sample id'),
          ),
        ),
      );
    });
  });
}

Future<File> _writeTempCsv(List<String> lines) async {
  final file = File(
    '${Directory.systemTemp.path}/astra_codec_${DateTime.now().microsecondsSinceEpoch}.csv',
  );
  await file.writeAsString(lines.join('\n'));
  return file;
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
