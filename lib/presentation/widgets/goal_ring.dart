import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../cubits/today_state.dart';
import '../formatters/step_count_formatter.dart';
import 'animated_step_count.dart';
import 'goal_ring_effects.dart';

const _kRingStrokeWidth = 9.0;
const _kRingMinDiameter = 220.0;
const _kRingMaxDiameter = 260.0;

/// Progress arc opacity when goal not yet reached (Figma / Story 5.8).
const _kRingProgressOpacityInProgress = 0.66;

const _kMicroTickMs = 150;
const _kLiveCoalesceMs = 100;
const _kLiveArcTweenMs = 200;
const _kOverflowAmbientCycleMs = 3200;

/// In-session step increases at or below this delta use micro-tick; above uses
/// easeInOut count-up (e.g. post-sync catch-up). Tune with Baptiste if needed.
const _kLiveMicroTickMaxDelta = 15;

@visibleForTesting
bool useMicroTickForLiveDelta(int delta) {
  return delta > 0 && delta <= _kLiveMicroTickMaxDelta;
}

@visibleForTesting
int countUpDurationMs(int delta) {
  if (delta <= 0) {
    return 0;
  }
  return (delta * 1.5).round().clamp(600, 1800);
}

@visibleForTesting
int tabReturnDurationMs(int delta) {
  if (delta <= 0) {
    return 0;
  }
  return (delta * 1.5).round().clamp(100, 1800);
}

class GoalRing extends StatefulWidget {
  const GoalRing({
    required this.state,
    this.userPreferences,
    this.localDayIso,
    this.showRing = true,
    this.freezeMotion = false,
    this.debugLastDisplayedSteps,
    super.key,
  });

  @visibleForTesting
  static bool disableStepPersistence = false;

  /// Test-only: skip prefs I/O and seed [lastDisplayedSteps] for cold-start tests.
  final int? debugLastDisplayedSteps;

  final TodayState state;
  final UserPreferencesRepository? userPreferences;
  final String? localDayIso;
  final bool showRing;
  final bool freezeMotion;

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

class _GoalRingState extends State<GoalRing> with TickerProviderStateMixin {
  AnimationController? _pulseController;
  AnimationController? _countUpController;
  AnimationController? _microTickController;
  AnimationController? _liveArcController;
  AnimationController? _overflowController;

  int _lastDisplayedSteps = 0;
  int _displayedSteps = 0;
  int? _microTickPreviousSteps;
  double _animatedProgress = 0;
  bool _prefsLoaded = false;
  bool _prefsLoadHandled = false;
  bool _coldStartHandled = false;
  int? _lastPersistedSteps;
  Timer? _liveCoalesceTimer;
  int? _pendingLiveSteps;

  @override
  void initState() {
    super.initState();
    if (widget.freezeMotion) {
      _displayedSteps = _targetSteps;
      _animatedProgress = _targetProgressRatio;
      _prefsLoaded = true;
      _coldStartHandled = true;
      _lastDisplayedSteps = _targetSteps;
    } else if (widget.debugLastDisplayedSteps != null) {
      final seed = widget.debugLastDisplayedSteps!;
      _lastDisplayedSteps = seed;
      _displayedSteps = seed;
      _animatedProgress = _progressRatioFor(seed);
      _prefsLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _prefsLoadHandled) {
          return;
        }
        _prefsLoadHandled = true;
        _afterLastDisplayedStepsLoaded();
      });
    } else {
      // Hold at zero until prefs resolve — avoids flashing the target count.
      _displayedSteps = 0;
      _animatedProgress = 0;
      unawaited(_loadLastDisplayedSteps());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseAnimation();
    _syncOverflowAnimation();
  }

  @override
  void didUpdateWidget(covariant GoalRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulseAnimation();
    _syncOverflowAnimation();

    if (oldWidget.localDayIso != widget.localDayIso) {
      _coldStartHandled = false;
      _prefsLoadHandled = false;
      _lastDisplayedSteps = 0;
      unawaited(_loadLastDisplayedSteps());
    }

    _handleStepChange(
      oldStatus: oldWidget.state.status,
      oldSteps: oldWidget.state.steps,
    );
  }

  Future<void> _loadLastDisplayedSteps() async {
    final debugSeed = widget.debugLastDisplayedSteps;
    if (debugSeed != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastDisplayedSteps = debugSeed;
        _displayedSteps = debugSeed;
        _animatedProgress = _progressRatioFor(debugSeed);
        _prefsLoaded = true;
      });
      _scheduleAfterPrefsLoaded();
      return;
    }
    if (GoalRing.disableStepPersistence) {
      if (!mounted) {
        return;
      }
      setState(() => _prefsLoaded = true);
      _scheduleAfterPrefsLoaded();
      return;
    }
    final prefs = widget.userPreferences;
    final day = widget.localDayIso;
    if (prefs == null || day == null) {
      if (!mounted) {
        return;
      }
      setState(() => _prefsLoaded = true);
      _scheduleAfterPrefsLoaded();
      return;
    }

    final stored = await prefs.getLastDisplayedSteps(day);
    if (!mounted) {
      return;
    }
    setState(() {
      _lastDisplayedSteps = stored ?? 0;
      _displayedSteps = _lastDisplayedSteps;
      _animatedProgress = _progressRatioFor(_lastDisplayedSteps);
      _prefsLoaded = true;
    });
    _scheduleAfterPrefsLoaded();
  }

  void _scheduleAfterPrefsLoaded() {
    if (_prefsLoadHandled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_prefsLoaded || _prefsLoadHandled) {
        return;
      }
      _prefsLoadHandled = true;
      _afterLastDisplayedStepsLoaded();
    });
  }

  void _afterLastDisplayedStepsLoaded() {
    if (GoalRing.disableStepPersistence &&
        widget.debugLastDisplayedSteps == null) {
      _coldStartHandled = true;
      _setDisplayedInstant(_targetSteps);
      return;
    }
    _handleStepChange(
      oldStatus: TodayStatus.loading,
      oldSteps: 0,
      forceColdStart: true,
    );
  }

  void _handleStepChange({
    required TodayStatus oldStatus,
    required int oldSteps,
    bool forceColdStart = false,
  }) {
    if (widget.freezeMotion) {
      return;
    }
    if (!_prefsLoaded) {
      return;
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = _targetSteps;
    final status = widget.state.status;

    if (status == TodayStatus.loading || status == TodayStatus.noPermission) {
      return;
    }

    if (target == 0 && _displayedSteps > 0) {
      _resetDisplayed(instant: true);
      return;
    }

    if (reduceMotion) {
      _setDisplayedInstant(target);
      return;
    }

    final isColdStart =
        forceColdStart ||
        (!_coldStartHandled &&
            oldStatus == TodayStatus.loading &&
            status != TodayStatus.loading);

    if (isColdStart) {
      _coldStartHandled = true;
      final start = _lastDisplayedSteps;
      if (start == target) {
        _setDisplayedInstant(target);
        return;
      }
      _runCountUp(from: start, to: target, coldStart: true);
      return;
    }

    if (target == _displayedSteps) {
      return;
    }

    if (target > _displayedSteps) {
      final delta = target - _displayedSteps;
      if (_countUpController?.isAnimating == true) {
        _pendingLiveSteps = target;
        return;
      }
      if (useMicroTickForLiveDelta(delta)) {
        _scheduleLiveUpdate(target);
      } else {
        _runCountUp(from: _displayedSteps, to: target, coldStart: false);
      }
      return;
    }

    _setDisplayedInstant(target);
  }

  void _scheduleLiveUpdate(int target) {
    _pendingLiveSteps = target;
    _liveCoalesceTimer?.cancel();
    _liveCoalesceTimer = Timer(
      const Duration(milliseconds: _kLiveCoalesceMs),
      () {
        if (!mounted || _pendingLiveSteps == null) {
          return;
        }
        final next = _pendingLiveSteps!;
        _pendingLiveSteps = null;
        if (next == _displayedSteps) {
          return;
        }
        _runMicroTick(from: _displayedSteps, to: next);
      },
    );
  }

  void _runCountUp({
    required int from,
    required int to,
    required bool coldStart,
  }) {
    _countUpController?.dispose();
    _microTickController?.dispose();
    _microTickPreviousSteps = null;

    final delta = to - from;
    if (delta <= 0) {
      _setDisplayedInstant(to);
      return;
    }

    final durationMs = coldStart
        ? countUpDurationMs(delta)
        : tabReturnDurationMs(delta);

    _countUpController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..addListener(_onCountUpTick);

    final goal = widget.state.goal;
    final fromRatio = goal > 0 ? (from / goal).clamp(0.0, 1.0) : 0.0;
    final toRatio = goal > 0 ? (to / goal).clamp(0.0, 1.0) : 0.0;

    _countUpController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _displayedSteps = to;
        _animatedProgress = toRatio;
        _lastDisplayedSteps = to;
        unawaited(_persistLastDisplayedSteps(to));
        _countUpController?.dispose();
        _countUpController = null;
        final pending = _pendingLiveSteps;
        if (pending != null && pending != to) {
          _pendingLiveSteps = null;
          _scheduleLiveUpdate(pending);
        }
      }
    });

    _countUpFrom = from;
    _countUpTo = to;
    _countUpFromRatio = fromRatio;
    _countUpToRatio = toRatio;
    _countUpController!.forward();
  }

  int _countUpFrom = 0;
  int _countUpTo = 0;
  double _countUpFromRatio = 0;
  double _countUpToRatio = 0;

  void _onCountUpTick() {
    final t = Curves.easeInOut.transform(_countUpController!.value);
    setState(() {
      _displayedSteps = (_countUpFrom + (_countUpTo - _countUpFrom) * t).round();
      _animatedProgress =
          _countUpFromRatio + (_countUpToRatio - _countUpFromRatio) * t;
    });
  }

  void _runMicroTick({required int from, required int to}) {
    _countUpController?.dispose();
    _countUpController = null;

    _microTickController?.dispose();
    _microTickPreviousSteps = from;
    _displayedSteps = to;
    _lastDisplayedSteps = to;

    _liveArcController?.dispose();
    final goal = widget.state.goal;
    final fromRatio = goal > 0 ? (from / goal).clamp(0.0, 1.0) : 0.0;
    final toRatio = goal > 0 ? (to / goal).clamp(0.0, 1.0) : 0.0;
    _liveArcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kLiveArcTweenMs),
    )..addListener(() {
        final t = Curves.easeOut.transform(_liveArcController!.value);
        setState(() {
          _animatedProgress = fromRatio + (toRatio - fromRatio) * t;
        });
      });

    _microTickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kMicroTickMs),
    )..addListener(() => setState(() {}));

    void onMicroTickDone(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _microTickPreviousSteps = null;
        _animatedProgress = toRatio;
        unawaited(_persistLastDisplayedSteps(to));
      }
    }

    _microTickController!.addStatusListener(onMicroTickDone);
    _liveArcController!.forward();
    _microTickController!.forward();
  }

  void _setDisplayedInstant(int steps) {
    _countUpController?.dispose();
    _countUpController = null;
    _microTickController?.dispose();
    _microTickController = null;
    _microTickPreviousSteps = null;
    _liveArcController?.dispose();
    _liveArcController = null;

    setState(() {
      _displayedSteps = steps;
      _animatedProgress = _progressRatioFor(steps);
      _lastDisplayedSteps = steps;
    });
    unawaited(_persistLastDisplayedSteps(steps));
  }

  void _resetDisplayed({required bool instant}) {
    _liveCoalesceTimer?.cancel();
    _pendingLiveSteps = null;
    if (instant) {
      _setDisplayedInstant(0);
    }
  }

  Future<void> _persistLastDisplayedSteps(int steps) async {
    if (GoalRing.disableStepPersistence ||
        _lastPersistedSteps == steps) {
      return;
    }
    final prefs = widget.userPreferences;
    final day = widget.localDayIso;
    if (prefs == null || day == null || !mounted) {
      return;
    }
    await prefs.setLastDisplayedSteps(localDayIso: day, steps: steps);
    if (!mounted) {
      return;
    }
    _lastPersistedSteps = steps;
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

  void _syncOverflowAnimation() {
    if (widget.freezeMotion) {
      _overflowController?.dispose();
      _overflowController = null;
      return;
    }
    final shouldAnimate = widget.state.status == TodayStatus.overflow;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (shouldAnimate && !disableAnimations) {
      _overflowController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: _kOverflowAmbientCycleMs),
      )..repeat();
    } else {
      _overflowController?.dispose();
      _overflowController = null;
    }
  }

  int get _targetSteps {
    return switch (widget.state.status) {
      TodayStatus.loading => 0,
      TodayStatus.noPermission => 0,
      TodayStatus.empty => 0,
      _ => widget.state.steps,
    };
  }

  double get _targetProgressRatio => GoalRing.ringProgressFor(widget.state);

  double get _effectiveProgress {
    if (widget.state.status == TodayStatus.loading ||
        widget.state.status == TodayStatus.noPermission) {
      return 0;
    }
    if (widget.freezeMotion) {
      return _targetProgressRatio;
    }
    if (widget.state.status == TodayStatus.empty && _displayedSteps == 0) {
      return 0;
    }
    return _animatedProgress;
  }

  double _progressRatioFor(int steps) {
    final goal = widget.state.goal;
    if (goal <= 0) {
      return 0;
    }
    return (steps / goal).clamp(0.0, 1.0);
  }

  @override
  void deactivate() {
    if (!widget.freezeMotion) {
      unawaited(_persistLastDisplayedSteps(_displayedSteps));
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _liveCoalesceTimer?.cancel();
    _pulseController?.dispose();
    _countUpController?.dispose();
    _microTickController?.dispose();
    _liveArcController?.dispose();
    _overflowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

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
                  if (widget.showRing)
                    _buildRing(size, colors, reduceMotion),
                  _buildCenterContent(colors, reduceMotion),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRing(Size size, AstraColors colors, bool reduceMotion) {
    final status = widget.state.status;
    final goalReached =
        status == TodayStatus.goalMet || status == TodayStatus.overflow;
    final progressColor = colors.accentPrimary.withValues(
      alpha: goalReached ? 1.0 : _kRingProgressOpacityInProgress,
    );
    final ring = CustomPaint(
      size: size,
      painter: GoalRingPainter(
        progress: _effectiveProgress,
        trackColor: colors.bgSubtle,
        progressColor: progressColor,
        strokeWidth: _kRingStrokeWidth,
        dashedTrack: status == TodayStatus.noPermission,
      ),
    );

    Widget result = ring;

    if (status == TodayStatus.loading && _pulseController != null) {
      result = FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.85).animate(
          CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
        ),
        child: result,
      );
    }

    if (status == TodayStatus.overflow &&
        !reduceMotion &&
        _overflowController != null) {
      final phase = _overflowController!.value;
      final strength = 0.12 + 0.08 * math.sin(phase * math.pi * 2);
      result = Stack(
        alignment: Alignment.center,
        children: [
          result,
          CustomPaint(
            size: size,
            painter: GoalRingOverflowAmbientPainter(
              color: colors.accentPrimary,
              strokeWidth: _kRingStrokeWidth,
              phase: phase,
              strength: strength,
            ),
          ),
        ],
      );
    }

    return result;
  }

  Widget _buildCenterContent(AstraColors colors, bool reduceMotion) {
    final status = widget.state.status;
    final centerText = switch (status) {
      TodayStatus.loading => '',
      TodayStatus.noPermission => '--',
      TodayStatus.empty => formatStepCount(0),
      _ => null,
    };

    final stepCountStyle = AstraTypography.displayFor(colors).copyWith(
      fontWeight: FontWeight.w900,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsFill.sneakerMove,
                size: 20,
                color: colors.neutralGray,
              ),
              const SizedBox(width: AstraSpacing.kSpaceXs),
              Text('Steps', style: AstraTypography.captionFor(colors)),
            ],
          ),
          const SizedBox(height: 4),
          if (centerText != null)
            Text(centerText, style: stepCountStyle)
          else if (reduceMotion || widget.freezeMotion)
            Text(formatStepCount(_targetSteps), style: stepCountStyle)
          else
            AnimatedStepCount(
              value: _displayedSteps,
              previousValue: _microTickPreviousSteps,
              microTickProgress: _microTickController?.value ?? 0,
              style: stepCountStyle,
            ),
          const SizedBox(height: 2),
          Text(
            '/${formatStepCount(widget.state.goal)}',
            style: AstraTypography.captionFor(colors),
          ),
        ],
      ),
    );
  }

  String get _semanticsLabel {
    final steps = _targetSteps;
    return switch (widget.state.status) {
      TodayStatus.loading => 'Steps today: loading',
      TodayStatus.noPermission => 'Steps today: permission required',
      TodayStatus.overflow ||
      TodayStatus.goalMet =>
        'Steps today: $steps. Daily goal ${widget.state.goal} reached.',
      _ => 'Steps today: $steps of ${widget.state.goal}',
    };
  }

  String? get _semanticsValue {
    return switch (widget.state.status) {
      TodayStatus.loading || TodayStatus.noPermission => null,
      _ => _targetSteps.toString(),
    };
  }

  String? get _semanticsDecreasedValue {
    return switch (widget.state.status) {
      TodayStatus.progress ||
      TodayStatus.goalMet ||
      TodayStatus.overflow ||
      TodayStatus.empty => '0',
      _ => null,
    };
  }

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
