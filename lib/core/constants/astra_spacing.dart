/// ASTRA spacing and radius design tokens (UX §1.4).
/// All values are logical pixels (dp).
abstract final class AstraSpacing {
  // Spacing scale (4px grid)
  static const double kSpaceXs = 4;
  static const double kSpaceSm = 8;
  static const double kSpaceMd = 16;
  static const double kSpaceLg = 24;
  static const double kSpaceXl = 32;
  static const double kSpace2xl = 48;

  /// Minimum horizontal padding on scaffold screens (AC #3).
  static const double kScreenHorizontalPadding = kSpaceMd;

  /// Minimum touch target for interactive controls (AC #3).
  static const double kMinTouchTarget = kSpace2xl;

  // Corner radii
  static const double kRadiusSm = 8;
  static const double kRadiusMd = 12;
  static const double kRadiusLg = 16;
  static const double kRadiusFull = 999;
}
