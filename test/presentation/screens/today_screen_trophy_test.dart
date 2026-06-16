import 'package:astra_app/presentation/models/week_day_status.dart';
import 'package:astra_app/presentation/screens/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countWeekGoalsMet', () {
    WeekDayStatus day({
      required bool isFuture,
      required bool goalMet,
    }) {
      return WeekDayStatus(
        localDay: DateTime.utc(2026, 6, 2),
        weekdayLabel: 'MON',
        dayNumber: 2,
        isToday: false,
        isFuture: isFuture,
        goalMet: goalMet,
      );
    }

    test('counts past and today goalMet days, excludes future', () {
      final days = [
        day(isFuture: false, goalMet: true),
        day(isFuture: false, goalMet: true),
        day(isFuture: false, goalMet: false),
        day(isFuture: true, goalMet: true),
      ];

      expect(countWeekGoalsMet(days), 2);
    });

    test('returns zero when no days met goal', () {
      final days = [
        day(isFuture: false, goalMet: false),
        day(isFuture: true, goalMet: false),
      ];

      expect(countWeekGoalsMet(days), 0);
    });
  });
}
