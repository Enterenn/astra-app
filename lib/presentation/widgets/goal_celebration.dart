import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_state.dart';
import 'goal_ring.dart';

const _kCelebrationSequenceMs = 2500;
const _kReducedMotionCopyFadeMs = 500;
const _kRingMinDiameter = 220.0;
const _kRingMaxDiameter = 260.0;

double _ringDiameter(double maxWidth) =>
    (maxWidth * 0.6).clamp(_kRingMinDiameter, _kRingMaxDiameter);

class GoalCelebration extends StatefulWidget {
  const GoalCelebration({
    required this.state,
    required this.onComplete,
    super.key,
  });

  final TodayState state;
  final VoidCallback onComplete;

  @visibleForTesting
  static const celebrationSequenceDuration = Duration(
    milliseconds: _kCelebrationSequenceMs,
  );

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

class _GoalCelebrationState extends State<GoalCelebration>
    with TickerProviderStateMixin {
  AnimationController? _sequenceController;
  Timer? _sequenceTimer;
  Timer? _hapticTimer;
  bool _hapticFired = false;
  bool _onCompleteCalled = false;
  bool _sequenceStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sequenceStarted) {
      _sequenceStarted = true;
      _startSequence();
    }
  }

  void _startSequence() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? const Duration(milliseconds: _kReducedMotionCopyFadeMs)
        : GoalCelebration.celebrationSequenceDuration;

    _sequenceController?.dispose();
    _sequenceController = AnimationController(vsync: this, duration: duration)
      ..forward();

    _sequenceTimer?.cancel();
    _sequenceTimer = Timer(duration, _finishSequence);

    if (!reduceMotion) {
      _scheduleHaptic();
    }
  }

  void _scheduleHaptic() {
    _hapticTimer?.cancel();
    _hapticTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _hapticFired) {
        return;
      }
      _hapticFired = true;
      if (Platform.isAndroid) {
        HapticFeedback.lightImpact();
      } else if (Platform.isIOS) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _finishSequence() {
    if (!mounted || _onCompleteCalled) {
      return;
    }
    _completeSequence();
  }

  void _completeSequence() {
    if (_onCompleteCalled) {
      return;
    }
    _onCompleteCalled = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _hapticTimer?.cancel();
    if (_sequenceStarted && !_onCompleteCalled) {
      _completeSequence();
    }
    _sequenceController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = context.astraColors;
    final controller = _sequenceController;

    return Semantics(
      liveRegion: true,
      label: 'Daily goal reached',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller == null)
            GoalRing(state: widget.state)
          else if (reduceMotion)
            _buildReducedMotionRing(colors)
          else
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) => _buildAnimatedRing(
                context,
                colors,
                controller.value,
              ),
            ),
          const SizedBox(height: 12),
          if (controller != null)
            _buildMicroCopy(colors, controller, reduceMotion: reduceMotion),
        ],
      ),
    );
  }

  Widget _buildReducedMotionRing(AstraColors colors) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = _ringDiameter(constraints.maxWidth);
          return SizedBox(
            width: diameter,
            height: diameter,
            child: GoalRing(state: widget.state),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedRing(
    BuildContext context,
    AstraColors colors,
    double t,
  ) {
    final ringScale = _pulseScale(
      t,
      durationMs: 600,
      peak: 1.05,
      curve: Curves.easeOutCubic,
    );
    final glowOpacity = _pulseOpacity(t, durationMs: 800, peak: 0.18);
    final shimmerStrength = _windowPulse(
      t,
      startMs: 200,
      endMs: 700,
      peak: 0.25,
    );
    final centerScale = _pulseScale(
      t,
      durationMs: 500,
      startMs: 100,
      peak: 1.02,
      curve: Curves.easeInOut,
    );

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = _ringDiameter(constraints.maxWidth);
          final size = Size.square(diameter);
          final progress = widget.state.progressRatio;

          return SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (glowOpacity > 0)
                  ExcludeSemantics(
                    child: Opacity(
                      opacity: glowOpacity,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          width: diameter,
                          height: diameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: ringScale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: centerScale,
                        child: GoalRing(state: widget.state),
                      ),
                      if (shimmerStrength > 0)
                        CustomPaint(
                          size: size,
                          painter: _CelebrationShimmerPainter(
                            progress: progress,
                            color: colors.accentPrimary,
                            shimmerStrength: shimmerStrength,
                            strokeWidth: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMicroCopy(
    AstraColors colors,
    AnimationController controller, {
    required bool reduceMotion,
  }) {
    final opacity = reduceMotion
        ? CurvedAnimation(parent: controller, curve: Curves.easeInOut).value
        : _microCopyOpacity(controller.value);

    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          'Daily goal reached',
          style: AstraTypography.captionFor(colors).copyWith(
            color: colors.neutralGray,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  double _microCopyOpacity(double t) {
    const fadeInEnd = 500 / _kCelebrationSequenceMs;
    const fadeOutStart = 2000 / _kCelebrationSequenceMs;
    if (t <= fadeInEnd) {
      return t / fadeInEnd;
    }
    if (t >= fadeOutStart) {
      return (1 - t) / (1 - fadeOutStart);
    }
    return 1;
  }

  double _pulseOpacity(
    double t, {
    required int durationMs,
    required double peak,
    Curve curve = Curves.easeOut,
  }) {
    final end = durationMs / _kCelebrationSequenceMs;
    if (t <= 0 || t >= end) {
      return 0;
    }
    final local = t / end;
    final shaped = local <= 0.5
        ? curve.transform(local * 2)
        : curve.transform((1 - local) * 2);
    return peak * shaped;
  }

  double _pulseScale(
    double t, {
    required int durationMs,
    int startMs = 0,
    required double peak,
    Curve curve = Curves.linear,
  }) {
    final start = startMs / _kCelebrationSequenceMs;
    final end = (startMs + durationMs) / _kCelebrationSequenceMs;
    if (t <= start || t >= end) {
      return 1;
    }
    final local = (t - start) / (end - start);
    final shaped = local <= 0.5
        ? curve.transform(local * 2)
        : curve.transform((1 - local) * 2);
    return 1 + (peak - 1) * shaped;
  }

  double _windowPulse(
    double t, {
    required int startMs,
    required int endMs,
    required double peak,
  }) {
    final start = startMs / _kCelebrationSequenceMs;
    final end = endMs / _kCelebrationSequenceMs;
    if (t < start || t > end) {
      return 0;
    }
    final local = (t - start) / (end - start);
    final shaped = local <= 0.5 ? local * 2 : (1 - local) * 2;
    return peak * Curves.easeInOut.transform(shaped);
  }
}

class _CelebrationShimmerPainter extends CustomPainter {
  _CelebrationShimmerPainter({
    required this.progress,
    required this.color,
    required this.shimmerStrength,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double shimmerStrength;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final alpha = (255 * (1 + shimmerStrength).clamp(0.0, 1.25))
        .round()
        .clamp(0, 255);

    final paint = Paint()
      ..color = color.withAlpha(alpha)
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
  bool shouldRepaint(covariant _CelebrationShimmerPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        shimmerStrength != oldDelegate.shimmerStrength;
  }
}
