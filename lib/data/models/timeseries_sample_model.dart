import '../../core/time/timestamp_codec.dart';
import 'normalized_step_bucket.dart';

class TimeseriesSampleModel {
  const TimeseriesSampleModel({
    required this.id,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.type,
    required this.value,
    required this.unit,
    required this.resolution,
    required this.provider,
    required this.deviceId,
    required this.zoneOffset,
  });

  final String id;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String type;
  final num value;
  final String unit;
  final String resolution;
  final String provider;
  final String deviceId;
  final String zoneOffset;

  factory TimeseriesSampleModel.fromNormalizedBucket({
    required NormalizedStepBucket bucket,
    required String id,
  }) {
    TimestampCodec.parseZoneOffset(bucket.zoneOffset);
    return TimeseriesSampleModel(
      id: id,
      startTimeUtc: bucket.startTimeUtc,
      endTimeUtc: bucket.endTimeUtc,
      type: bucket.type,
      value: bucket.value,
      unit: bucket.unit,
      resolution: bucket.resolution,
      provider: bucket.provider,
      deviceId: bucket.deviceId,
      zoneOffset: bucket.zoneOffset,
    );
  }

  factory TimeseriesSampleModel.fromMap(Map<String, Object?> map) {
    return TimeseriesSampleModel(
      id: map['id']! as String,
      startTimeUtc: TimestampCodec.parseUtc(map['start_time']! as String),
      endTimeUtc: TimestampCodec.parseUtc(map['end_time']! as String),
      type: map['type']! as String,
      value: map['value']! as num,
      unit: map['unit']! as String,
      resolution: map['resolution']! as String,
      provider: map['provider']! as String,
      deviceId: map['device_id']! as String,
      zoneOffset: map['zone_offset']! as String,
    );
  }

  Map<String, Object?> toMap() {
    TimestampCodec.parseZoneOffset(zoneOffset);
    return {
      'id': id,
      'start_time': TimestampCodec.formatUtc(startTimeUtc),
      'end_time': TimestampCodec.formatUtc(endTimeUtc),
      'type': type,
      'value': value,
      'unit': unit,
      'resolution': resolution,
      'provider': provider,
      'device_id': deviceId,
      'zone_offset': zoneOffset,
    };
  }
}
