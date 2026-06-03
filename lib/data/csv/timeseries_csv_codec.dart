import 'dart:io';

import '../../core/time/timestamp_codec.dart';
import '../models/normalized_step_bucket.dart';
import '../models/timeseries_sample_model.dart';
import 'import_validation_exception.dart';

/// OW-aligned CSV serialization for [timeseries_samples] export/import (FR-19).
class TimeseriesCsvCodec {
  const TimeseriesCsvCodec._();

  static const headerRow =
      'id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset';

  static const _headerColumns = [
    'id',
    'start_time',
    'end_time',
    'type',
    'value',
    'unit',
    'resolution',
    'provider',
    'device_id',
    'zone_offset',
  ];

  static const _allowedResolutions = {
    kFiveMinuteResolution,
    kHourlyResolution,
    kDailyResolution,
  };

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String serializeRow(TimeseriesSampleModel sample) {
    final map = sample.toMap();
    final fields = _headerColumns.map((column) {
      if (column == 'value') {
        return _formatValue(
          map['type']! as String,
          map['value']! as num,
        );
      }
      return map[column]!.toString();
    });
    return fields.map(_escapeField).join(',');
  }

  /// Reads and validates an entire import file (RFC 4180 records, UTF-8 BOM).
  static Future<List<TimeseriesSampleModel>> parseImportFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ImportValidationException('CSV file not found');
    }

    final content = stripUtf8Bom(await file.readAsString());
    if (content.trim().isEmpty) {
      throw ImportValidationException('CSV file is empty');
    }

    final records = splitCsvRecords(content);
    if (records.isEmpty) {
      throw ImportValidationException('CSV file is empty');
    }

    parseHeaderRow(records.first);

    final samples = <TimeseriesSampleModel>[];
    var dataRowNumber = 0;
    for (var i = 1; i < records.length; i++) {
      if (records[i].trim().isEmpty) {
        continue;
      }
      dataRowNumber++;
      samples.add(
        parseDataRow(records[i], rowNumber: dataRowNumber),
      );
    }
    return samples;
  }

  /// Strips a leading UTF-8 BOM (common in Excel exports).
  static String stripUtf8Bom(String content) {
    if (content.startsWith('\uFEFF')) {
      return content.substring(1);
    }
    return content;
  }

  /// Splits file content into RFC 4180 records (newlines inside quotes stay in-record).
  static List<String> splitCsvRecords(String content) {
    final records = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < content.length) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            buffer.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          buffer.write(char);
          i++;
          continue;
        }
        buffer.write(char);
        i++;
        continue;
      }

      if (char == '"') {
        inQuotes = true;
        buffer.write(char);
        i++;
        continue;
      }
      if (char == '\r' || char == '\n') {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        records.add(buffer.toString());
        buffer.clear();
        i++;
        continue;
      }
      buffer.write(char);
      i++;
    }

    if (buffer.isNotEmpty) {
      records.add(buffer.toString());
    }
    return records;
  }

  /// Parses and validates the header line (exact OW column order).
  static void parseHeaderRow(String line) {
    final fields = parseCsvFields(stripUtf8Bom(line).replaceAll('\r', ''));
    if (fields.length != _headerColumns.length) {
      throw ImportValidationException(
        'CSV header must have ${_headerColumns.length} columns',
      );
    }
    for (var i = 0; i < _headerColumns.length; i++) {
      if (fields[i] != _headerColumns[i]) {
        throw ImportValidationException(
          'CSV header column ${i + 1} must be "${_headerColumns[i]}"',
        );
      }
    }
  }

  /// Parses one data row; [rowNumber] is 1-based index among data rows (for errors).
  static TimeseriesSampleModel parseDataRow(String line, {required int rowNumber}) {
    try {
      final fields = parseCsvFields(line.replaceAll('\r', ''));
      if (fields.length != _headerColumns.length) {
        throw ImportValidationException(
          'Row $rowNumber: expected ${_headerColumns.length} columns',
        );
      }

      final map = <String, Object?>{
        for (var i = 0; i < _headerColumns.length; i++)
          _headerColumns[i]: fields[i],
      };

      _validateDataMap(map, rowNumber: rowNumber);
      return TimeseriesSampleModel.fromMap(map);
    } on ImportValidationException {
      rethrow;
    } catch (error) {
      throw ImportValidationException('Row $rowNumber: invalid data ($error)');
    }
  }

  /// RFC 4180 field split (handles quoted commas, quotes, newlines, carriage returns).
  static List<String> parseCsvFields(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < line.length) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        buffer.write(char);
        i++;
        continue;
      }

      if (char == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (char == ',') {
        fields.add(buffer.toString());
        buffer.clear();
        i++;
        continue;
      }
      buffer.write(char);
      i++;
    }

    fields.add(buffer.toString());
    return fields;
  }

  static void _validateDataMap(
    Map<String, Object?> map, {
    required int rowNumber,
  }) {
    void requireNonEmpty(String key) {
      final value = map[key];
      if (value == null || value.toString().trim().isEmpty) {
        throw ImportValidationException('Row $rowNumber: $key is required');
      }
    }

    for (final key in _headerColumns) {
      requireNonEmpty(key);
    }

    final id = map['id']! as String;
    if (!_uuidPattern.hasMatch(id)) {
      throw ImportValidationException(
        'Row $rowNumber: id must be a valid UUID',
      );
    }

    final type = map['type']! as String;
    if (type != kStepSampleType) {
      throw ImportValidationException(
        'Row $rowNumber: type must be "$kStepSampleType" in Phase 0',
      );
    }

    final valueRaw = map['value']! as String;
    final parsedValue = int.tryParse(valueRaw);
    if (parsedValue == null || parsedValue < 0) {
      throw ImportValidationException(
        'Row $rowNumber: value must be a non-negative integer',
      );
    }
    map['value'] = parsedValue;

    final unit = map['unit']! as String;
    if (unit != kStepSampleUnit) {
      throw ImportValidationException(
        'Row $rowNumber: unit must be "$kStepSampleUnit"',
      );
    }

    final resolution = map['resolution']! as String;
    if (!_allowedResolutions.contains(resolution)) {
      throw ImportValidationException(
        'Row $rowNumber: resolution must be one of ${_allowedResolutions.join(", ")}',
      );
    }

    final startTime = TimestampCodec.parseUtc(map['start_time']! as String);
    final endTime = TimestampCodec.parseUtc(map['end_time']! as String);
    if (endTime.isBefore(startTime)) {
      throw ImportValidationException(
        'Row $rowNumber: end_time must not be before start_time',
      );
    }
    TimestampCodec.parseZoneOffset(map['zone_offset']! as String);
  }

  static String _formatValue(String type, num value) {
    if (type == kStepSampleType) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// RFC 4180 field escaping.
  static String _escapeField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
