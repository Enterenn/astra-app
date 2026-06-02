import 'package:astra_app/core/time/time_provider.dart';

class FakeTimeProvider implements TimeProvider {
  FakeTimeProvider({
    required DateTime fixedNowUtc,
    required Duration zoneOffset,
  }) : this._(fixedNowUtc.toUtc(), zoneOffset);

  FakeTimeProvider._(this._fixedNowUtc, this._zoneOffset);

  final DateTime _fixedNowUtc;
  final Duration _zoneOffset;

  @override
  DateTime nowUtc() => _fixedNowUtc;

  @override
  Duration currentZoneOffset() => _zoneOffset;
}
