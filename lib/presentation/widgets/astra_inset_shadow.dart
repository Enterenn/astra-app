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
  double? _devicePixelRatio;

  bool isValid(Size size, BorderRadius borderRadius, double devicePixelRatio) =>
      insetShadowCacheMatches(
        size: size,
        borderRadius: borderRadius,
        devicePixelRatio: devicePixelRatio,
        cachedSize: _size,
        cachedBorderRadius: _borderRadius,
        cachedDevicePixelRatio: _devicePixelRatio,
        hasImage: _image != null,
      );

  void update(
    ui.Image image,
    Size size,
    BorderRadius borderRadius,
    double devicePixelRatio,
  ) {
    _image?.dispose();
    _image = image;
    _size = size;
    _borderRadius = borderRadius;
    _devicePixelRatio = devicePixelRatio;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _size = null;
    _borderRadius = null;
    _devicePixelRatio = null;
  }
}

/// Shared cache-key logic for [_InsetShadowCache] — exposed for unit tests.
@visibleForTesting
bool insetShadowCacheMatches({
  required Size size,
  required BorderRadius borderRadius,
  required double devicePixelRatio,
  required Size? cachedSize,
  required BorderRadius? cachedBorderRadius,
  required double? cachedDevicePixelRatio,
  required bool hasImage,
}) =>
    hasImage &&
    cachedSize == size &&
    cachedBorderRadius == borderRadius &&
    cachedDevicePixelRatio == devicePixelRatio;

ui.Image _rasterizeInsetShadowPicture({
  required ui.Picture picture,
  required Size logicalSize,
  required double devicePixelRatio,
}) {
  final image = picture.toImageSync(
    (logicalSize.width * devicePixelRatio).ceil(),
    (logicalSize.height * devicePixelRatio).ceil(),
  );
  picture.dispose();
  return image;
}

void _blitInsetShadowImage(Canvas canvas, ui.Image image, Size logicalSize) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height),
    Paint(),
  );
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
  double devicePixelRatio,
  _InsetShadowCache cache,
) {
  if (size.isEmpty) return;

  if (cache.isValid(size, borderRadius, devicePixelRatio)) {
    _blitInsetShadowImage(canvas, cache._image!, size);
    return;
  }

  final recorder = ui.PictureRecorder();
  final tmpCanvas = Canvas(recorder)..scale(devicePixelRatio);
  _renderAstraInsetShadow(tmpCanvas, clipPath);
  final picture = recorder.endRecording();
  final image = _rasterizeInsetShadowPicture(
    picture: picture,
    logicalSize: size,
    devicePixelRatio: devicePixelRatio,
  );
  cache.update(image, size, borderRadius, devicePixelRatio);

  _blitInsetShadowImage(canvas, image, size);
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
    final devicePixelRatio = View.of(context).devicePixelRatio;
    return CustomPaint(
      painter: _AstraInsetShadowSurfacePainter(
        color: widget.color,
        borderRadius: br,
        devicePixelRatio: devicePixelRatio,
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
    required this.devicePixelRatio,
    required this.shadowCache,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double devicePixelRatio;
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
      devicePixelRatio,
      shadowCache,
    );
  }

  @override
  bool shouldRepaint(covariant _AstraInsetShadowSurfacePainter old) =>
      astraInsetShadowPainterShouldRepaint(
        oldColor: old.color,
        newColor: color,
        oldBorderRadius: old.borderRadius,
        newBorderRadius: borderRadius,
      );
}

/// Shared repaint decision for [_AstraInsetShadowSurfacePainter] — exposed for unit tests.
@visibleForTesting
bool astraInsetShadowPainterShouldRepaint({
  required Color oldColor,
  required Color newColor,
  required BorderRadius oldBorderRadius,
  required BorderRadius newBorderRadius,
}) =>
    oldColor != newColor || oldBorderRadius != newBorderRadius;
