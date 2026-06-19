import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'astra_inset_shadow.dart';

/// Bitmap cache for [paintGoalRingTrackInnerShadow].
///
/// Create once in [_GoalRingState] and dispose in [State.dispose].
/// The shadow is static between layout changes, so it is rendered once
/// into a [ui.Image] and re-drawn with a cheap [Canvas.drawImage] call on
/// every subsequent frame (REF-08 / NFR-REF-01).
class GoalRingInsetShadowCache {
  ui.Image? _image;
  Size? _size;

  /// Returns true when the cached bitmap matches [size] and can be reused.
  bool isValid(Size size) => _image != null && _size == size;

  /// Stores [image] as the cached bitmap for [size], disposing the previous one.
  void update(ui.Image image, Size size) {
    _image?.dispose();
    _image = image;
    _size = size;
  }

  /// Releases the cached bitmap. Call from [State.dispose].
  void dispose() {
    _image?.dispose();
    _image = null;
    _size = null;
  }
}

/// Paints an inset shadow at the top of the goal ring track (annulus).
///
/// On the first call (or after [size] changes), the shadow is rendered into an
/// offscreen bitmap via [ui.Picture.toImageSync] and stored in [cache].
/// Subsequent frames with the same size call [Canvas.drawImage] — one trivially
/// cheap GPU blit instead of a full [ui.ImageFilter.blur] save-layer.
///
/// Technique: clip to the annulus, then draw only the **top half arc** of the
/// outer circle as a thick blurred stroke shifted down by [kAstraInsetShadowOffsetY].
/// The blur bleeds inward from the top only — no artefact at the bottom.
void paintGoalRingTrackInnerShadow(
  Canvas canvas,
  Path annulusPath,
  Offset center,
  double innerRadius,
  double outerRadius,
  Size size,
  GoalRingInsetShadowCache cache,
) {
  if (size.isEmpty) return;

  if (cache.isValid(size)) {
    canvas.drawImage(cache._image!, Offset.zero, Paint());
    return;
  }

  // First paint (or after size change): render shadow into an offscreen bitmap.
  final recorder = ui.PictureRecorder();
  final tmpCanvas = Canvas(recorder);
  _renderGoalRingInsetShadow(tmpCanvas, annulusPath, center, innerRadius, outerRadius);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
  picture.dispose();
  cache.update(image, size);

  canvas.drawImage(image, Offset.zero, Paint());
}

/// Renders the inset shadow onto [canvas].
///
/// This is the extracted core of the original [paintGoalRingTrackInnerShadow].
/// The clip + blur are applied directly to [canvas] — when called from a
/// [ui.PictureRecorder] canvas the resulting [ui.Picture] already contains
/// transparent pixels outside the annulus, so the bitmap can be blitted
/// directly onto the main canvas without any additional clipping.
void _renderGoalRingInsetShadow(
  Canvas canvas,
  Path annulusPath,
  Offset center,
  double innerRadius,
  double outerRadius,
) {
  canvas.save();
  canvas.clipPath(annulusPath);

  final shadowPaint = Paint()
    ..color = kAstraInsetShadowColor.withValues(alpha: kAstraInsetShadowOpacity)
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: kAstraInsetShadowBlur / 2,
      sigmaY: kAstraInsetShadowBlur / 2,
    )
    ..strokeWidth = 8.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Top-half arc of the outer circle: 9 o'clock → 12 o'clock → 3 o'clock.
  // In Flutter canvas angles, 0 = 3 o'clock, π = 9 o'clock (clockwise).
  // Sweeping π clockwise from π passes through 3π/2 (top/12 o'clock) to 2π/0.
  final topArc = Path()
    ..arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      math.pi, // start at 9 o'clock
      math.pi, // sweep CW through 12 o'clock to 3 o'clock
      false,
    );

  canvas.save();
  canvas.translate(0, kAstraInsetShadowOffsetY);
  canvas.drawPath(topArc, shadowPaint);
  canvas.restore();

  canvas.restore();
}

/// Shared ring stroke effects for celebration and overflow ambient motion.
class GoalRingShimmerPainter extends CustomPainter {
  GoalRingShimmerPainter({
    required this.progress,
    required this.color,
    required this.shimmerStrength,
    required this.strokeWidth,
    this.phase = 0,
  });

  final double progress;
  final Color color;
  final double shimmerStrength;
  final double strokeWidth;
  final double phase;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || shimmerStrength <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final alpha = (255 * shimmerStrength.clamp(0.0, 1.0)).round().clamp(0, 255);

    final paint = Paint()
      ..color = color.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = _fullSweep * progress.clamp(0.0, 1.0);
    final start = _startAngle + phase * _fullSweep;
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant GoalRingShimmerPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        shimmerStrength != oldDelegate.shimmerStrength ||
        strokeWidth != oldDelegate.strokeWidth ||
        phase != oldDelegate.phase;
  }
}

/// Animates the remaining arc segment to a full ring during celebration.
class GoalRingArcSweepPainter extends CustomPainter {
  GoalRingArcSweepPainter({
    required this.fromProgress,
    required this.toProgress,
    required this.sweepT,
    required this.color,
    required this.strokeWidth,
  });

  final double fromProgress;
  final double toProgress;
  final double sweepT;
  final Color color;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final eased = Curves.easeInOut.transform(sweepT.clamp(0.0, 1.0));
    final progress = fromProgress + (toProgress - fromProgress) * eased;

    if (progress <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _startAngle,
      _fullSweep * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GoalRingArcSweepPainter oldDelegate) {
    return fromProgress != oldDelegate.fromProgress ||
        toProgress != oldDelegate.toProgress ||
        sweepT != oldDelegate.sweepT ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Calm ambient shimmer for overflow state (slow loop).
class GoalRingOverflowAmbientPainter extends CustomPainter {
  GoalRingOverflowAmbientPainter({
    required this.color,
    required this.strokeWidth,
    required this.phase,
    required this.strength,
  });

  final Color color;
  final double strokeWidth;
  final double phase;
  final double strength;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final alpha = (255 * strength.clamp(0.0, 0.35)).round().clamp(0, 255);

    final paint = Paint()
      ..color = color.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final highlightSweep = _fullSweep * 0.18;
    final start = _startAngle + phase * _fullSweep;
    canvas.drawArc(rect, start, highlightSweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant GoalRingOverflowAmbientPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        phase != oldDelegate.phase ||
        strength != oldDelegate.strength;
  }
}
