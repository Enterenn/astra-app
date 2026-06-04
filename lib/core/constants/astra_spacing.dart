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

  /// Floating pill nav bar (Story 5.7).
  static const double kBottomNavBarHeight = 72;
  static const double kBottomNavHorizontalPadding = 24;

  /// Offset from bottom safe area to the floating pill (Figma).
  static const double kBottomNavBottomOffset = kSpaceXl;

  static const double kBottomNavItemSize = 52;
  static const double kBottomNavIconLabelGap = 6;

  /// Active tab squircle corner radius (= kRadiusLg = 16px).
  static const double kBottomNavSquircleRadius = kRadiusLg;

  /// Figma corner smoothing for active tab squircle (0–1, spec = 100%).
  static const double kBottomNavSquircleSmoothing = 1.0;
}
