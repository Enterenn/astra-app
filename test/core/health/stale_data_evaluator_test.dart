import 'package:astra_app/core/health/stale_data_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isStaleData', () {
    final now = DateTime.utc(2026, 6, 2, 12);

    test('returns false when lastIngestionUtc is null', () {
      expect(
        isStaleData(lastIngestionUtc: null, nowUtc: now, isIos: false),
        isFalse,
      );
      expect(
        isStaleData(lastIngestionUtc: null, nowUtc: now, isIos: true),
        isFalse,
      );
    });

    group('Android (12h threshold)', () {
      test('returns false at exactly 12 hours', () {
        final last = now.subtract(const Duration(hours: 12));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: false),
          isFalse,
        );
      });

      test('returns true just past 12 hours', () {
        final last = now.subtract(const Duration(hours: 12, minutes: 1));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: false),
          isTrue,
        );
      });

      test('returns false when ingestion is recent', () {
        final last = now.subtract(const Duration(hours: 6));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: false),
          isFalse,
        );
      });
    });

    group('iOS (4h threshold)', () {
      test('returns false at exactly 4 hours', () {
        final last = now.subtract(const Duration(hours: 4));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: true),
          isFalse,
        );
      });

      test('returns true just past 4 hours', () {
        final last = now.subtract(const Duration(hours: 4, minutes: 1));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: true),
          isTrue,
        );
      });

      test('returns false when ingestion is recent', () {
        final last = now.subtract(const Duration(hours: 2));
        expect(
          isStaleData(lastIngestionUtc: last, nowUtc: now, isIos: true),
          isFalse,
        );
      });
    });
  });
}
