import 'package:astra_app/core/ids/sample_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../time/fake_time_provider.dart';

void main() {
  group('SampleIdGenerator', () {
    test('nextId returns base36 microsecond timestamp on first call', () {
      final fixed = DateTime.utc(2026, 6, 18, 12, 0, 0, 123, 456);
      final clock = FakeTimeProvider(
        fixedNowUtc: fixed,
        zoneOffset: Duration.zero,
      );
      final generator = SampleIdGenerator(clock);

      expect(
        generator.nextId(),
        fixed.microsecondsSinceEpoch.toRadixString(36),
      );
    });

    test('nextId appends sequence suffix when same microsecond is reused', () {
      final fixed = DateTime.utc(2026, 6, 18, 12, 0, 0);
      final clock = FakeTimeProvider(
        fixedNowUtc: fixed,
        zoneOffset: Duration.zero,
      );
      final generator = SampleIdGenerator(clock);
      final base = fixed.microsecondsSinceEpoch.toRadixString(36);

      final first = generator.nextId();
      final second = generator.nextId();
      final third = generator.nextId();

      expect(first, base);
      expect(second, '$base-1');
      expect(third, '$base-2');
      expect({first, second, third}, hasLength(3));
    });

    test('deterministicFromStartUtc is stable and normalizes to UTC', () {
      final start = DateTime.utc(2026, 1, 15, 8, 30);

      expect(
        SampleIdGenerator.deterministicFromStartUtc(start),
        start.microsecondsSinceEpoch.toRadixString(36),
      );
      expect(
        SampleIdGenerator.deterministicFromStartUtc(
          DateTime(2026, 1, 15, 9, 30),
        ),
        start.microsecondsSinceEpoch.toRadixString(36),
      );
    });

    test('deterministicFromStartUtc differs for distinct bucket starts', () {
      final a = DateTime.utc(2026, 6, 1, 0, 0);
      final b = DateTime.utc(2026, 6, 1, 0, 5);

      expect(
        SampleIdGenerator.deterministicFromStartUtc(a),
        isNot(SampleIdGenerator.deterministicFromStartUtc(b)),
      );
    });
  });
}
