import 'dart:math' as math;

import 'package:flutter/material.dart';

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
