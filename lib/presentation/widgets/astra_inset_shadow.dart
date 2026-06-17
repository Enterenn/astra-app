import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';

/// Figma inset shadow — offset X:0, Y:4px, blur:8px, #323337 at 8%.
const kAstraInsetShadowColor = Color(0xFF323337);
const kAstraInsetShadowOpacity = 0.08;
const kAstraInsetShadowOffsetY = 4.0;
const kAstraInsetShadowBlur = 8.0;

/// Paints an inset shadow clipped to [clipPath].
///
/// Technique: clip to shape → draw the shape's own outline as a thick stroke,
/// translated by [kAstraInsetShadowOffsetY] downward, with an [ImageFilter.blur]
/// so it bleeds inward from the top edge only.  Drawn as a background layer so
/// opaque children (e.g. the segmented-control thumb) cover it naturally.
void paintAstraInsetShadowOnPath(Canvas canvas, Path clipPath) {
  final bounds = clipPath.getBounds();
  if (bounds.isEmpty) return;

  final shadowPaint = Paint()
    ..color = kAstraInsetShadowColor.withValues(alpha: kAstraInsetShadowOpacity)
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: kAstraInsetShadowBlur / 2,
      sigmaY: kAstraInsetShadowBlur / 2,
    )
    ..strokeWidth = 6.0
    ..style = PaintingStyle.stroke;

  // Shadow path = shape outline + large outer rect (closes open contours and
  // fills gaps at rounded corners when the path has an evenOdd fill rule).
  final shadowPath = Path()
    ..addPath(clipPath, Offset.zero)
    ..addRect(bounds.inflate(40.0));

  canvas.save();
  canvas.clipPath(clipPath); // constrain shadow inside the shape

  canvas.save();
  canvas.translate(0, kAstraInsetShadowOffsetY); // Y offset
  canvas.drawPath(shadowPath, shadowPaint);
  canvas.restore();

  canvas.restore();
}

/// Surface with bgSubtle fill + Figma inset shadow rendered as a background
/// painter — opaque children (thumb, etc.) naturally cover the shadow.
class AstraInsetShadowSurface extends StatelessWidget {
  const AstraInsetShadowSurface({
    required this.color,
    required this.child,
    this.borderRadius,
    super.key,
  });

  final Color color;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AstraSpacing.kRadiusFull);
    return CustomPaint(
      painter: _AstraInsetShadowSurfacePainter(color: color, borderRadius: br),
      child: child,
    );
  }
}

class _AstraInsetShadowSurfacePainter extends CustomPainter {
  const _AstraInsetShadowSurfacePainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rrect = borderRadius.toRRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final path = Path()..addRRect(rrect);

    // Background fill
    canvas.drawRRect(rrect, Paint()..color = color);

    // Inset shadow on top of fill, behind child
    paintAstraInsetShadowOnPath(canvas, path);
  }

  @override
  bool shouldRepaint(covariant _AstraInsetShadowSurfacePainter old) =>
      color != old.color || borderRadius != old.borderRadius;
}
