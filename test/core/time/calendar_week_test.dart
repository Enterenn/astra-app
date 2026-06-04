import 'package:astra_app/core/time/calendar_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarWeek.daysContaining', () {
    test('returns Mon–Sun for a Wednesday reference', () {
      // 2026-06-03 is Wednesday (UTC date-only key).
      final wednesday = DateTime.utc(2026, 6, 3);
      final days = CalendarWeek.daysContaining(wednesday);

      expect(days, hasLength(7));
      expect(days.first, DateTime.utc(2026, 6, 1));
      expect(days.last, DateTime.utc(2026, 6, 7));
      expect(days[2], wednesday);
    });

    test('returns Mon–Sun when reference is Monday', () {
      final monday = DateTime.utc(2026, 6, 1);
      final days = CalendarWeek.daysContaining(monday);

      expect(days.first, monday);
      expect(days.last, DateTime.utc(2026, 6, 7));
    });
  });
}
