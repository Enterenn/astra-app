import 'package:flutter/material.dart';

import 'astra_colors.dart';

/// Typography tokens (UX §1.3). Colors follow active [AstraColors] theme.
abstract final class AstraTypography {
  static const String figtree = 'Figtree';
  static const String darkerGrotesque = 'Darker Grotesque';

  static TextStyle displayFor(AstraColors colors) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 52,
    fontWeight: FontWeight.w600,
    height: 1.05,
    color: colors.textPrimary,
  );

  /// Today goal ring step count (Darker Grotesque Black 64px).
  static TextStyle goalRingStepCountFor(AstraColors colors) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1.05,
    color: colors.textPrimary,
  );

  /// Goal ring "Steps" label and `/goal` line (Figtree 16px medium).
  static TextStyle goalRingLabelFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: colors.neutralGray,
  );

  static TextStyle titleFor(AstraColors colors) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: colors.textPrimary,
  );

  /// Onboarding intro headline (Figtree 24px semibold).
  static TextStyle onboardingIntroTitleFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: colors.textPrimary,
  );

  static TextStyle headlineFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: colors.textPrimary,
  );

  static TextStyle bodyFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.textPrimary,
  );

  static TextStyle screenTitleFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: colors.neutralGray,
  );

  static TextStyle labelFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: colors.textPrimary,
  );

  static TextStyle captionFor(AstraColors colors) => TextStyle(
    fontFamily: figtree,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: colors.neutralGray,
  );

  static TextStyle dataFor(AstraColors colors) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: colors.textPrimary,
  );

  static TextStyle display(BuildContext context) =>
      displayFor(context.astraColors);

  static TextStyle title(BuildContext context) => titleFor(context.astraColors);

  static TextStyle headline(BuildContext context) =>
      headlineFor(context.astraColors);

  static TextStyle body(BuildContext context) => bodyFor(context.astraColors);

  static TextStyle screenTitle(BuildContext context) =>
      screenTitleFor(context.astraColors);

  static TextStyle label(BuildContext context) => labelFor(context.astraColors);

  static TextStyle caption(BuildContext context) =>
      captionFor(context.astraColors);

  static TextStyle data(BuildContext context) => dataFor(context.astraColors);
}
