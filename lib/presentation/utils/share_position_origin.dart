import 'package:flutter/material.dart';

/// Anchor rect for iOS/iPadOS share sheets ([ShareParams.sharePositionOrigin]).
///
/// Falls back to a 1×1 rect when the widget is not laid out yet (required on
/// recent iOS when the origin would otherwise be zero).
Rect sharePositionOriginFor(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final size = renderObject.size;
    if (size.width > 0 && size.height > 0) {
      return renderObject.localToGlobal(Offset.zero) & size;
    }
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
