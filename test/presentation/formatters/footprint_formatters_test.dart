import 'package:astra_app/presentation/formatters/file_size_formatter.dart';
import 'package:astra_app/presentation/formatters/relative_time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRelativeTime', () {
    final nowUtc = DateTime.utc(2026, 6, 3, 12);

    test('returns never when instant is null', () {
      expect(
        formatRelativeTime(instantUtc: null, nowUtc: nowUtc),
        'never',
      );
    });

    test('returns just now for sub-minute elapsed time', () {
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.subtract(const Duration(seconds: 30)),
          nowUtc: nowUtc,
        ),
        'just now',
      );
    });

    test('returns minutes ago for sub-hour elapsed time', () {
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.subtract(const Duration(minutes: 14)),
          nowUtc: nowUtc,
        ),
        '14 minutes ago',
      );
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.subtract(const Duration(minutes: 1)),
          nowUtc: nowUtc,
        ),
        '1 minute ago',
      );
    });

    test('returns hours ago for sub-day elapsed time', () {
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.subtract(const Duration(hours: 3)),
          nowUtc: nowUtc,
        ),
        '3 hours ago',
      );
    });

    test('returns days ago for multi-day elapsed time', () {
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.subtract(const Duration(days: 2)),
          nowUtc: nowUtc,
        ),
        '2 days ago',
      );
    });

    test('returns just now when instant is in the future', () {
      expect(
        formatRelativeTime(
          instantUtc: nowUtc.add(const Duration(minutes: 5)),
          nowUtc: nowUtc,
        ),
        'just now',
      );
    });
  });

  group('formatFileSize', () {
    test('formats bytes', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(0), '0 B');
    });

    test('formats kilobytes as integer', () {
      expect(formatFileSize(2048), '2 KB');
    });

    test('formats megabytes with one decimal', () {
      expect(formatFileSize(2516582), '2.4 MB');
    });

    test('formats gigabytes with one decimal', () {
      expect(formatFileSize(1610612736), '1.5 GB');
    });

    test('clamps negative values to zero bytes', () {
      expect(formatFileSize(-1), '0 B');
    });
  });
}
