import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/helpers/collection_health_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveCollectionHealthDisplay', () {
    test('loading takes priority over stale and permission', () {
      expect(
        deriveCollectionHealthDisplay(
          status: TodayStatus.loading,
          isStale: true,
        ),
        CollectionHealthDisplay.loading,
      );
    });

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
