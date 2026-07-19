/// Immutable UTC instant and zone offset captured from [TimeProvider.snapshot].
class TimeSnapshot {
  TimeSnapshot({required DateTime nowUtc, required this.zoneOffset})
    : nowUtc = nowUtc.toUtc();

  final DateTime nowUtc;
  final Duration zoneOffset;
}

abstract class TimeProvider {
  DateTime nowUtc();
  Duration currentZoneOffset();

  TimeSnapshot snapshot() {
    return TimeSnapshot(nowUtc: nowUtc(), zoneOffset: currentZoneOffset());
  }
}
