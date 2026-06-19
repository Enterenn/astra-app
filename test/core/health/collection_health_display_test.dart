import 'package:astra_app/core/health/collection_health_display.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveCollectionHealthDisplay', () {
    test('permission denied takes priority over stale', () {
      expect(
        deriveCollectionHealthDisplay(
          status: TodayStatus.noPermission,
          isStale: true,
        ),
        CollectionHealthDisplay.permissionDenied,
      );
    });

    test('stale when permission granted and isStale true', () {
      expect(
        deriveCollectionHealthDisplay(
          status: TodayStatus.progress,
          isStale: true,
        ),
        CollectionHealthDisplay.stale,
      );
    });

    test('active when permission granted and fresh data', () {
      expect(
        deriveCollectionHealthDisplay(
          status: TodayStatus.progress,
          isStale: false,
        ),
        CollectionHealthDisplay.active,
      );
    });
  });
}
