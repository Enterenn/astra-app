import 'package:astra_app/core/time/local_day_boundary.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localDayBoundary', () {
    test('hasLocalDayChanged is false when previous is null', () {
      final snapshot = TimeSnapshot(
        nowUtc: DateTime.utc(2026, 6, 8, 10),
        zoneOffset: const Duration(hours: 2),
      );
      expect(
        hasLocalDayChanged(previousDayIso: null, snapshot: snapshot),
        isFalse,
      );
    });

    test('hasLocalDayChanged detects day change', () {
      final snapshot = TimeSnapshot(
        nowUtc: DateTime.utc(2026, 6, 8, 0, 9),
        zoneOffset: const Duration(hours: 2),
      );
      expect(
        hasLocalDayChanged(previousDayIso: '2026-06-07', snapshot: snapshot),
        isTrue,
      );
      expect(
        hasLocalDayChanged(previousDayIso: '2026-06-08', snapshot: snapshot),
        isFalse,
      );
    });

    test('untilNextLocalMidnight counts down to next local midnight', () {
      final snapshot = TimeSnapshot(
        nowUtc: DateTime.utc(2026, 6, 7, 20),
        zoneOffset: const Duration(hours: 2),
      );
      expect(
        untilNextLocalMidnight(snapshot),
        const Duration(hours: 2),
      );
    });

    test('untilNextLocalMidnight schedules the following day after rollover', () {
      final snapshot = TimeSnapshot(
        nowUtc: DateTime.utc(2026, 6, 7, 22),
        zoneOffset: const Duration(hours: 2),
      );
      expect(
        untilNextLocalMidnight(snapshot),
        const Duration(hours: 24),
      );
    });
  });
}
