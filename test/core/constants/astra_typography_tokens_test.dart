import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final colors = AstraColors.light();

  group('AstraTypography.navLabelFor', () {
    test('font size is 10', () {
      expect(AstraTypography.navLabelFor(colors).fontSize, 10);
    });

    test('font weight is w700', () {
      expect(AstraTypography.navLabelFor(colors).fontWeight, FontWeight.w700);
    });

    test('letter spacing is 0.4', () {
      expect(AstraTypography.navLabelFor(colors).letterSpacing, 0.4);
    });

    test('height is 1.2', () {
      expect(AstraTypography.navLabelFor(colors).height, 1.2);
    });

    test('font family is Figtree', () {
      expect(AstraTypography.navLabelFor(colors).fontFamily, AstraTypography.figtree);
    });
  });

  group('AstraTypography.weekDayNumberFor', () {
    test('font size is 16', () {
      expect(AstraTypography.weekDayNumberFor(colors).fontSize, 16);
    });

    test('font weight is w900', () {
      expect(AstraTypography.weekDayNumberFor(colors).fontWeight, FontWeight.w900);
    });

    test('height is 1.0', () {
      expect(AstraTypography.weekDayNumberFor(colors).height, 1.0);
    });

    test('font family is Figtree', () {
      expect(AstraTypography.weekDayNumberFor(colors).fontFamily, AstraTypography.figtree);
    });
  });
}
