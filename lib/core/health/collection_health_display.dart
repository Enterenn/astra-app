import '../../presentation/cubits/today_state.dart';

enum CollectionHealthDisplay { active, stale, permissionDenied }

CollectionHealthDisplay deriveCollectionHealthDisplay({
  required TodayStatus status,
  required bool isStale,
}) {
  if (status == TodayStatus.noPermission) {
    return CollectionHealthDisplay.permissionDenied;
  }
  if (isStale) {
    return CollectionHealthDisplay.stale;
  }
  return CollectionHealthDisplay.active;
}
