import 'package:astra_app/core/time/local_day_formatter.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatLocalDayIso', () {
    test('formats local day from snapshot zone offset', () {
      final snapshot = TimeSnapshot(
        nowUtc: DateTime.utc(2026, 6, 1, 22),
        zoneOffset: const Duration(hours: 2),
      );

      expect(formatLocalDayIso(snapshot), '2026-06-02');
    });
  });
}
