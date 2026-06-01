/// ASTRA spacing and radius design tokens.
/// All values are logical pixels.
abstract final class AstraSpacing {
  // Spacing scale (4px grid)
  static const double kSpaceXs = 4;
  static const double kSpaceSm = 8;
  static const double kSpaceMd = 16;
  static const double kSpaceLg = 24;
  static const double kSpaceXl = 32;
  static const double kSpace2xl = 48;

  /// Minimum horizontal padding on scaffold screens.
  static const double kScreenHorizontalPadding = kSpaceMd;

  /// Minimum touch target for interactive controls.
  static const double kMinTouchTarget = kSpace2xl;

  // Corner radius
  static const double kRadiusSm = 8;
  static const double kRadiusMd = 12;
  static const double kRadiusLg = 16;
  static const double kRadiusFull = 999;

  /// Height of the bottom tab bar.
  static const double kBottomTabBarHeight = 56;
}
