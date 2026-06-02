import 'package:astra_app/core/time/system_time_provider.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_time_provider.dart';

void main() {
  group('TimeProvider', () {
    test('SystemTimeProvider returns UTC now and the current local offset', () {
      final provider = SystemTimeProvider();

      final nowUtc = provider.nowUtc();
      final expectedOffset = DateTime.now().timeZoneOffset;

      expect(provider, isA<TimeProvider>());
      expect(nowUtc.isUtc, isTrue);
      expect(provider.currentZoneOffset(), expectedOffset);
    });

    test('FakeTimeProvider returns deterministic time and offset', () {
      final provider = FakeTimeProvider(
        fixedNowUtc: DateTime.parse('2026-06-02T07:00:00Z'),
        zoneOffset: const Duration(hours: 2),
      );

      expect(provider, isA<TimeProvider>());
      expect(provider.nowUtc(), DateTime.utc(2026, 6, 2, 7));
      expect(provider.currentZoneOffset(), const Duration(hours: 2));
    });
  });
}
