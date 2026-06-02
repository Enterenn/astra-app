const kStepSampleType = 'steps';
const kStepSampleUnit = 'count';
const kFiveMinuteResolution = '5min';

class NormalizedStepBucket {
  NormalizedStepBucket({
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
    required this.value,
    required this.provider,
    required this.deviceId,
    required this.zoneOffset,
    this.type = kStepSampleType,
    this.unit = kStepSampleUnit,
    this.resolution = kFiveMinuteResolution,
  }) : startTimeUtc = startTimeUtc.toUtc(),
       endTimeUtc = endTimeUtc.toUtc() {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must be non-negative');
    }
  }

  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String type;
  final int value;
  final String unit;
  final String resolution;
  final String provider;
  final String deviceId;
  final String zoneOffset;
}
