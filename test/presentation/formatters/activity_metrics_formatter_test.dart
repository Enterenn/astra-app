import 'package:astra_app/presentation/formatters/activity_metrics_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatKcal', () {
    test('formats integer', () {
      expect(formatKcal(187), '187');
      expect(formatKcal(0), '0');
    });
  });

  group('formatDistanceKm', () {
    test('one decimal half-up', () {
      expect(formatDistanceKm(4.24), '4.2');
      expect(formatDistanceKm(4.25), '4.3');
      expect(formatDistanceKm(0), '0.0');
    });
  });

  group('formatWalkingDuration', () {
    test('zero', () {
      expect(formatWalkingDuration(Duration.zero), '00:00:00');
    });

    test('59 seconds', () {
      expect(formatWalkingDuration(const Duration(seconds: 59)), '00:00:59');
    });

    test('3661 seconds → 01:01:01', () {
      expect(formatWalkingDuration(const Duration(seconds: 3661)), '01:01:01');
    });

    test('37 minutes 20 seconds', () {
      expect(
        formatWalkingDuration(const Duration(minutes: 37, seconds: 20)),
        '00:37:20',
      );
    });
  });
}
