import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Single speck for the goal celebration radial burst.
class CelebrationParticleSpec {
  const CelebrationParticleSpec({
    required this.angle,
    required this.normalizedSpeed,
    required this.size,
    required this.startOffset,
    required this.lifespan,
    required this.useMutedColor,
    required this.useSparkle,
  });

  final double angle;
  final double normalizedSpeed;
  final double size;
  final double startOffset;
  final double lifespan;
  final bool useMutedColor;
  final bool useSparkle;
}

/// Normalized age at which particles begin their exit twinkle (firework ember).
const _kTwinkleStartAge = 0.58;

/// Deterministic particle field — stable across frames and hot reload.
List<CelebrationParticleSpec> generateCelebrationParticles({int count = 45}) {
  final random = math.Random(42);
  return List.generate(count, (_) {
    return CelebrationParticleSpec(
      angle: random.nextDouble() * math.pi * 2,
      normalizedSpeed: 0.4 + random.nextDouble() * 0.6,
      size: 1 + random.nextDouble() * 4,
      startOffset: 0.78 + random.nextDouble() * 0.22,
      lifespan: 0.20 + random.nextDouble() * 0.26,
      useMutedColor: random.nextDouble() > 0.45,
      useSparkle: random.nextDouble() > 0.82,
    );
  });
}

/// Radial accent burst around the goal ring during celebration.
class GoalCelebrationParticlesPainter extends CustomPainter {
  GoalCelebrationParticlesPainter({
    required this.t,
    required this.ringRadius,
    required this.primaryColor,
    required this.mutedColor,
    required this.sparkleColor,
    required this.particles,
  });

  final double t;
  final double ringRadius;
  final Color primaryColor;
  final Color mutedColor;
  final Color sparkleColor;
  final List<CelebrationParticleSpec> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final envelope = _burstEnvelope(t);
    if (envelope <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final birth = particle.startOffset * 0.018;
      final age = (t - birth) / particle.lifespan;
      if (age < 0 || age > 1) {
        continue;
      }

      final easedAge = Curves.easeOutQuart.transform(age);
      final drift = ringRadius * particle.normalizedSpeed * 0.72 * easedAge;
      final distance = ringRadius * particle.startOffset + drift;
      final gravity = easedAge * easedAge * ringRadius * 0.08;
      final offset = Offset(
        center.dx + math.cos(particle.angle) * distance,
        center.dy + math.sin(particle.angle) * distance + gravity,
      );

      var fade = (1 - age) * envelope;
      if (fade <= 0.02) {
        continue;
      }

      var baseColor = particle.useSparkle
          ? sparkleColor
          : particle.useMutedColor
          ? mutedColor
          : primaryColor;
      var radius = particle.size / 2;
      var alpha = fade * 0.9;

      if (age >= _kTwinkleStartAge) {
        final tail = (age - _kTwinkleStartAge) / (1 - _kTwinkleStartAge);
        final twinkle = _exitTwinkleWave(age, particle.angle);
        final intensity = particle.useSparkle ? 1.0 : 0.72;

        alpha *= (0.62 + (0.38 + 0.42 * intensity) * twinkle);
        baseColor = Color.lerp(
          baseColor,
          sparkleColor,
          (tail * twinkle * (0.45 + 0.35 * intensity)).clamp(0.0, 1.0),
        )!;
        radius *= 1 + (0.18 + 0.12 * intensity) * tail * twinkle;
      }

      if (alpha <= 0.02) {
        continue;
      }

      final paint = Paint()
        ..color = baseColor.withValues(alpha: alpha.clamp(0.0, 1.0));

      if (particle.useSparkle) {
        canvas.drawCircle(offset, radius * 0.7, paint);
      } else {
        canvas.drawCircle(offset, radius, paint);
      }
    }
  }

  /// Fast deterministic flicker in the last portion of each particle's life.
  double _exitTwinkleWave(double age, double phase) {
    return 0.5 + 0.5 * math.sin(phase * 6.1 + age * 38);
  }

  double _burstEnvelope(double normalizedT) {
    if (normalizedT < 0.006) {
      return normalizedT / 0.006;
    }
    if (normalizedT < 0.38) {
      return 1;
    }
    if (normalizedT < 0.75) {
      return (0.75 - normalizedT) / 0.37;
    }
    return 0;
  }

  @override
  bool shouldRepaint(covariant GoalCelebrationParticlesPainter oldDelegate) {
    return t != oldDelegate.t ||
        ringRadius != oldDelegate.ringRadius ||
        primaryColor != oldDelegate.primaryColor ||
        mutedColor != oldDelegate.mutedColor ||
        sparkleColor != oldDelegate.sparkleColor;
  }
}
