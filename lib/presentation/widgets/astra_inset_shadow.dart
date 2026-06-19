import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/astra_spacing.dart';

/// Figma inset shadow — offset X:0, Y:4px, blur:8px, #323337 at 8%.
const kAstraInsetShadowColor = Color(0xFF323337);
const kAstraInsetShadowOpacity = 0.08;
const kAstraInsetShadowOffsetY = 4.0;
const kAstraInsetShadowBlur = 8.0;

/// Bitmap cache for inset shadows in [AstraInsetShadowSurface].
class _InsetShadowCache {
  ui.Image? _image;
  Size? _size;
  BorderRadius? _borderRadius;

  bool isValid(Size size, BorderRadius borderRadius) =>
      _image != null && _size == size && _borderRadius == borderRadius;

  void update(ui.Image image, Size size, BorderRadius borderRadius) {
    _image?.dispose();
    _image = image;
    _size = size;
    _borderRadius = borderRadius;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _size = null;
    _borderRadius = null;
  }
}

/// Paints an inset shadow clipped to [clipPath].
///
/// No-cache fallback for direct calls without a [AstraInsetShadowSurface] context.
void paintAstraInsetShadowOnPath(Canvas canvas, Path clipPath) {
  final bounds = clipPath.getBounds();
  if (bounds.isEmpty) return;

  _renderAstraInsetShadow(canvas, clipPath);
}

void _paintAstraInsetShadowOnPathCached(
  Canvas canvas,
  Path clipPath,
  Size size,
  BorderRadius borderRadius,
  _InsetShadowCache cache,
) {
  if (size.isEmpty) return;

  if (cache.isValid(size, borderRadius)) {
    canvas.drawImage(cache._image!, Offset.zero, Paint());
    return;
  }

  final recorder = ui.PictureRecorder();
  final tmpCanvas = Canvas(recorder);
  _renderAstraInsetShadow(tmpCanvas, clipPath);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
  picture.dispose();
  cache.update(image, size, borderRadius);

  canvas.drawImage(image, Offset.zero, Paint());
}

void _renderAstraInsetShadow(Canvas canvas, Path clipPath) {
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
  canvas.clipPath(clipPath);

  canvas.save();
  canvas.translate(0, kAstraInsetShadowOffsetY);
  canvas.drawPath(shadowPath, shadowPaint);
  canvas.restore();

  canvas.restore();
}

/// Surface with bgSubtle fill + Figma inset shadow rendered as a background
/// painter — opaque children (thumb, etc.) naturally cover the shadow.
class AstraInsetShadowSurface extends StatefulWidget {
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
  State<AstraInsetShadowSurface> createState() => _AstraInsetShadowSurfaceState();
}

class _AstraInsetShadowSurfaceState extends State<AstraInsetShadowSurface> {
  final _shadowCache = _InsetShadowCache();

  @override
  void dispose() {
    _shadowCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(AstraSpacing.kRadiusFull);
    return CustomPaint(
      painter: _AstraInsetShadowSurfacePainter(
        color: widget.color,
        borderRadius: br,
        shadowCache: _shadowCache,
      ),
      child: widget.child,
    );
  }
}

class _AstraInsetShadowSurfacePainter extends CustomPainter {
  _AstraInsetShadowSurfacePainter({
    required this.color,
    required this.borderRadius,
    required this.shadowCache,
  });

  final Color color;
  final BorderRadius borderRadius;
  final _InsetShadowCache shadowCache;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rrect = borderRadius.toRRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final path = Path()..addRRect(rrect);

    canvas.drawRRect(rrect, Paint()..color = color);

    _paintAstraInsetShadowOnPathCached(
      canvas,
      path,
      size,
      borderRadius,
      shadowCache,
    );
  }

  @override
  bool shouldRepaint(covariant _AstraInsetShadowSurfacePainter old) =>
      color != old.color || borderRadius != old.borderRadius;
}
