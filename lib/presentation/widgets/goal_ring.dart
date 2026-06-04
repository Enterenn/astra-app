import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_state.dart';
import '../formatters/step_count_formatter.dart';

const _kRingStrokeWidth = 9.0;
const _kRingMinDiameter = 220.0;
const _kRingMaxDiameter = 260.0;

/// Progress arc opacity when goal not yet reached (Figma / Story 5.8).
const _kRingProgressOpacityInProgress = 0.66;

class GoalRing extends StatefulWidget {
  const GoalRing({required this.state, super.key});

  final TodayState state;

  @visibleForTesting
  static double ringProgressFor(TodayState state) {
    return switch (state.status) {
      TodayStatus.loading ||
      TodayStatus.noPermission ||
      TodayStatus.empty => 0,
      TodayStatus.progress ||
      TodayStatus.goalMet ||
      TodayStatus.overflow => state.progressRatio,
    };
  }

  @override
  State<GoalRing> createState() => _GoalRingState();
}

class _GoalRingState extends State<GoalRing> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant GoalRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulseAnimation();
  }

  void _syncPulseAnimation() {
    final shouldPulse = widget.state.status == TodayStatus.loading;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (shouldPulse && !disableAnimations) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    } else {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = (constraints.maxWidth * 0.6).clamp(
          _kRingMinDiameter,
          _kRingMaxDiameter,
        );
        final size = Size.square(diameter);

        return Semantics(
          label: _semanticsLabel,
          value: _semanticsValue,
          increasedValue: _semanticsMaxValue,
          decreasedValue: _semanticsDecreasedValue,
          container: true,
          child: ExcludeSemantics(
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRing(size, colors),
                  _buildCenterContent(colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRing(Size size, AstraColors colors) {
    final status = widget.state.status;
    final goalReached =
        status == TodayStatus.goalMet || status == TodayStatus.overflow;
    final progressColor = colors.accentPrimary.withValues(
      alpha: goalReached ? 1.0 : _kRingProgressOpacityInProgress,
    );
    final ring = CustomPaint(
      size: size,
      painter: GoalRingPainter(
        progress: GoalRing.ringProgressFor(widget.state),
        trackColor: colors.bgSubtle,
        progressColor: progressColor,
        strokeWidth: _kRingStrokeWidth,
        dashedTrack: status == TodayStatus.noPermission,
      ),
    );

    if (status == TodayStatus.loading && _pulseController != null) {
      return FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.85).animate(
          CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
        ),
        child: ring,
      );
    }

    return ring;
  }

  Widget _buildCenterContent(AstraColors colors) {
    final status = widget.state.status;
    final centerText = switch (status) {
      TodayStatus.loading => '',
      TodayStatus.noPermission => '--',
      TodayStatus.empty => formatStepCount(0),
      _ => formatStepCount(widget.state.steps),
    };

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (centerText.isNotEmpty)
            Text(centerText, style: AstraTypography.displayFor(colors))
          else
            SizedBox(height: AstraTypography.displayFor(colors).fontSize),
          const SizedBox(height: 4),
          Text('steps today', style: AstraTypography.captionFor(colors)),
          const SizedBox(height: 2),
          Text(
            'goal ${formatStepCount(widget.state.goal)}',
            style: AstraTypography.captionFor(colors),
          ),
        ],
      ),
    );
  }

  String get _semanticsLabel {
    return switch (widget.state.status) {
      TodayStatus.loading => 'Steps today: loading',
      TodayStatus.noPermission => 'Steps today: permission required',
      TodayStatus.overflow ||
      TodayStatus.goalMet =>
        'Steps today: ${widget.state.steps}. Daily goal ${widget.state.goal} reached.',
      _ => 'Steps today: ${widget.state.steps} of ${widget.state.goal}',
    };
  }

  String? get _semanticsValue {
    return switch (widget.state.status) {
      TodayStatus.loading || TodayStatus.noPermission => null,
      _ => widget.state.steps.toString(),
    };
  }

  /// Progress ring min (UX §4.3): 0.
  String? get _semanticsDecreasedValue {
    return switch (widget.state.status) {
      TodayStatus.progress ||
      TodayStatus.goalMet ||
      TodayStatus.overflow ||
      TodayStatus.empty => '0',
      _ => null,
    };
  }

  /// Progress ring max (UX §4.3): daily goal.
  String? get _semanticsMaxValue {
    return switch (widget.state.status) {
      TodayStatus.progress ||
      TodayStatus.goalMet ||
      TodayStatus.overflow ||
      TodayStatus.empty when widget.state.goal > 0 =>
        widget.state.goal.toString(),
      _ => null,
    };
  }
}

class GoalRingPainter extends CustomPainter {
  GoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.dashedTrack,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  final bool dashedTrack;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (dashedTrack) {
      _drawDashedArc(canvas, rect, trackPaint, _startAngle, _fullSweep);
    } else {
      canvas.drawArc(rect, _startAngle, _fullSweep, false, trackPaint);
    }

    if (progress <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _startAngle,
      _fullSweep * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double startAngle,
    double sweepAngle,
  ) {
    const dashLength = 8.0;
    const gapLength = 6.0;
    final path = Path()..addArc(rect, startAngle, sweepAngle);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoalRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashedTrack != oldDelegate.dashedTrack;
  }
}
