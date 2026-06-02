import 'package:astra_app/core/time/local_day_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDayCalculator', () {
    test('groups the same UTC instant by the immutable stored offset', () {
      final utc = DateTime.utc(2026, 6, 1, 22, 30);

      expect(
        LocalDayCalculator.localDay(utc: utc, zoneOffset: '+02:00'),
        DateTime.utc(2026, 6, 2),
      );
      expect(
        LocalDayCalculator.localDay(utc: utc, zoneOffset: '-05:00'),
        DateTime.utc(2026, 6, 1),
      );
    });

    test('uses the offset stored on each row across a DST boundary', () {
      expect(
        LocalDayCalculator.localDay(
          utc: DateTime.utc(2026, 3, 28, 23, 30),
          zoneOffset: '+01:00',
        ),
        DateTime.utc(2026, 3, 29),
      );
      expect(
        LocalDayCalculator.localDay(
          utc: DateTime.utc(2026, 3, 29, 22, 30),
          zoneOffset: '+02:00',
        ),
        DateTime.utc(2026, 3, 30),
      );
    });

    test('rejects offsets outside plus-or-minus HH:MM format', () {
      expect(
        () => LocalDayCalculator.localDay(
          utc: DateTime.utc(2026, 6, 2),
          zoneOffset: 'Z',
        ),
        throwsFormatException,
      );
    });
  });
}
