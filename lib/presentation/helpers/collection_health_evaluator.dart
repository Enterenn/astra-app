import '../cubits/today_state.dart';

enum CollectionHealthDisplay { loading, active, stale, permissionDenied }

CollectionHealthDisplay deriveCollectionHealthDisplay({
  required TodayStatus status,
  required bool isStale,
}) {
  if (status == TodayStatus.loading) {
    return CollectionHealthDisplay.loading;
  }
  if (status == TodayStatus.noPermission) {
    return CollectionHealthDisplay.permissionDenied;
  }
  if (isStale) {
    return CollectionHealthDisplay.stale;
  }
  return CollectionHealthDisplay.active;
}
