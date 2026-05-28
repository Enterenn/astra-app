import 'package:flutter/material.dart';

import 'astra_colors.dart';

/// Typography tokens (UX §1.3). Colors follow active [AstraColors] theme.
abstract final class AstraTypography {
  static const String figtree = 'Figtree';
  static const String darkerGrotesque = 'Darker Grotesque';

  static TextStyle display(BuildContext context) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 52,
    fontWeight: FontWeight.w600,
    height: 1.05,
    color: context.astraColors.textPrimary,
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: context.astraColors.textPrimary,
  );

  static TextStyle headline(BuildContext context) => TextStyle(
    fontFamily: figtree,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: context.astraColors.textPrimary,
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: figtree,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: context.astraColors.textPrimary,
  );

  static TextStyle label(BuildContext context) => TextStyle(
    fontFamily: figtree,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: context.astraColors.textPrimary,
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: figtree,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: context.astraColors.textSecondary,
  );

  static TextStyle data(BuildContext context) => TextStyle(
    fontFamily: darkerGrotesque,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: context.astraColors.textPrimary,
  );
}
