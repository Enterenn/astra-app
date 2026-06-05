import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_state.dart';
import 'goal_celebration_particles.dart';
import 'goal_ring.dart';
import 'goal_ring_effects.dart';

const _kCelebrationSequenceMs = 4000;
const _kReducedMotionCopyFadeMs = 500;
const _kArcSweepMs = 400;
const _kRingPulseMs = 720;
const _kRingPulsePeak = 1.08;
double _ringDiameter(double maxWidth) =>
    (maxWidth * kGoalRingWidthFactor).clamp(
      kGoalRingMinDiameter,
      kGoalRingMaxDiameter,
    );

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

  @visibleForTesting
  static final celebrationParticles = generateCelebrationParticles();

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
      _scheduleHaptics();
    }
  }

  void _scheduleHaptics() {
    _hapticTimer?.cancel();
    _hapticTimer = Timer(const Duration(milliseconds: 260), () {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = _ringDiameter(constraints.maxWidth);
          return SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (controller == null)
                  GoalRing(state: widget.state)
                else if (reduceMotion)
                  _buildReducedMotionRing(colors, diameter)
                else
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) => _buildAnimatedRing(
                      colors,
                      controller.value,
                      diameter,
                    ),
                  ),
                if (controller != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildMicroCopy(
                      colors,
                      controller,
                      reduceMotion: reduceMotion,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReducedMotionRing(AstraColors colors, double diameter) {
    return ExcludeSemantics(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: GoalRing(state: widget.state, freezeMotion: true),
      ),
    );
  }

  Widget _buildAnimatedRing(
    AstraColors colors,
    double t,
    double diameter,
  ) {
    final ringScale = _ringScale(t);
    final glowOpacity = _pulseOpacity(t, durationMs: 1200, peak: 0.30);
    final shimmerStrength = _windowPulse(
      t,
      startMs: 550,
      endMs: 1100,
      peak: 0.22,
    );
    final arcSweepT = (t * _kCelebrationSequenceMs / _kArcSweepMs).clamp(0.0, 1.0);
    final startProgress = widget.state.progressRatio.clamp(0.0, 1.0);
    final size = Size.square(diameter);
    final particleCanvas = diameter * 1.45;
    final ringRadius = (diameter - kGoalRingStrokeWidth) / 2;

    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (glowOpacity > 0)
            OverflowBox(
              maxWidth: diameter * 1.35,
              maxHeight: diameter * 1.35,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: glowOpacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
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
            ),
          Transform.scale(
            scale: ringScale,
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (arcSweepT < 1) ...[
                    CustomPaint(
                      size: size,
                      painter: GoalRingPainter(
                        progress: 0,
                        trackColor: colors.bgSubtle,
                        progressColor: colors.accentPrimary,
                        strokeWidth: kGoalRingStrokeWidth,
                        dashedTrack: false,
                      ),
                    ),
                    CustomPaint(
                      size: size,
                      painter: GoalRingArcSweepPainter(
                        fromProgress: startProgress,
                        toProgress: 1,
                        sweepT: arcSweepT,
                        color: colors.accentPrimary,
                        strokeWidth: kGoalRingStrokeWidth,
                      ),
                    ),
                  ] else
                    CustomPaint(
                      size: size,
                      painter: GoalRingPainter(
                        progress: 1,
                        trackColor: colors.bgSubtle,
                        progressColor: colors.accentPrimary,
                        strokeWidth: kGoalRingStrokeWidth,
                        dashedTrack: false,
                      ),
                    ),
                  GoalRing(
                    state: widget.state,
                    showRing: false,
                    freezeMotion: true,
                  ),
                  if (shimmerStrength > 0)
                    CustomPaint(
                      size: size,
                      painter: GoalRingShimmerPainter(
                        progress: 1,
                        color: colors.accentPrimary,
                        shimmerStrength: shimmerStrength,
                        strokeWidth: kGoalRingStrokeWidth,
                      ),
                    ),
                ],
              ),
            ),
          ),
          OverflowBox(
            maxWidth: particleCanvas,
            maxHeight: particleCanvas,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: Size.square(particleCanvas),
                painter: GoalCelebrationParticlesPainter(
                  t: t,
                  ringRadius: ringRadius * ringScale,
                  primaryColor: colors.accentPrimary,
                  mutedColor: colors.accentPrimaryMuted,
                  sparkleColor: colors.textPrimary.withValues(alpha: 0.55),
                  particles: GoalCelebration.celebrationParticles,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single smooth bump — sin envelope avoids the kink of the old triangle pulse.
  double _ringScale(double t) {
    final end = _kRingPulseMs / _kCelebrationSequenceMs;
    if (t <= 0 || t >= end) {
      return 1;
    }
    final bump = math.sin((t / end) * math.pi);
    return 1 + (_kRingPulsePeak - 1) * bump;
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
    const fadeOutStart = 3500 / _kCelebrationSequenceMs;
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
