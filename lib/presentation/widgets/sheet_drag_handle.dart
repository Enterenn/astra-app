import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';

/// Standard modal bottom sheet drag handle (32×4, radius 2).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  static const double _width = 32;
  static const double _height = 4;
  static const double _radius = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    return Center(
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: colors.borderDefault,
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }
}
