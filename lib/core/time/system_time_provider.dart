import 'time_provider.dart';

class SystemTimeProvider implements TimeProvider {
  const SystemTimeProvider();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration currentZoneOffset() => DateTime.now().timeZoneOffset;

  @override
  TimeSnapshot snapshot() {
    final now = DateTime.now();
    return TimeSnapshot(nowUtc: now.toUtc(), zoneOffset: now.timeZoneOffset);
  }
}
