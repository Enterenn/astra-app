import '../models/normalized_step_bucket.dart';
import '../models/timeseries_sample_model.dart';

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
