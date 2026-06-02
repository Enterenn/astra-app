import 'time_provider.dart';

class SystemTimeProvider implements TimeProvider {
  const SystemTimeProvider();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration currentZoneOffset() => DateTime.now().timeZoneOffset;
}
