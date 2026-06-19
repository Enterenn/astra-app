import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/debug/live_pipeline_log.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/today_state.dart';
import '../formatters/step_count_formatter.dart';
import 'animated_step_count.dart';
import 'goal_ring_effects.dart';

/// Figma Today screen progress ring stroke width.
const kGoalRingStrokeWidth = 24.0;

/// Ring diameter = card inner width × [kGoalRingWidthFactor], clamped to [min, max].
const kGoalRingMinDiameter = 240.0;
const kGoalRingMaxDiameter = 300.0;
const kGoalRingWidthFactor = 0.80;

/// Progress arc opacity when goal not yet reached (Figma / Story 5.8).
const _kRingProgressOpacityInProgress = 0.66;

const _kMicroTickMs = 150;
const _kLiveCoalesceMs = 100;
const _kLiveArcTweenMs = 200;
const _kOverflowAmbientCycleMs = 3200;

/// Delay before unlock catch-up so the count-up is visible after the OS wake
/// animation (Baptiste field test 2026-06-05).
const kForegroundCatchUpDelay = Duration(seconds: 1);

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
    this.showRing = true,
    this.freezeMotion = false,
    this.onForegroundCatchUpHandled,
    this.onLastDisplayedStepsChanged,
    super.key,
  });

  final TodayState state;
  final bool showRing;
  final bool freezeMotion;
  final VoidCallback? onForegroundCatchUpHandled;
  final ValueChanged<int>? onLastDisplayedStepsChanged;

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
  bool _displayStateHandled = false;
  bool _coldStartHandled = false;
  Timer? _liveCoalesceTimer;
  Timer? _foregroundCatchUpTimer;
  bool _foregroundCatchUpScheduled = false;
  bool _pendingForegroundCatchUpClear = false;
  int? _pendingLiveSteps;

  void _releaseCountUpController() {
    final controller = _countUpController;
    _countUpController = null;
    controller?.dispose();
  }

  void _releaseMicroTickController() {
    final controller = _microTickController;
    _microTickController = null;
    controller?.dispose();
  }

  void _releaseLiveArcController() {
    final controller = _liveArcController;
    _liveArcController = null;
    controller?.dispose();
  }

  void _releasePulseController() {
    final controller = _pulseController;
    _pulseController = null;
    controller?.dispose();
  }

  void _releaseOverflowController() {
    final controller = _overflowController;
    _overflowController = null;
    controller?.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.freezeMotion) {
      _displayedSteps = _targetSteps;
      _animatedProgress = _targetProgressRatio;
      _displayStateHandled = true;
      _coldStartHandled = true;
      _lastDisplayedSteps = _targetSteps;
    } else {
      // Hold at zero until cubit loads display prefs — avoids flashing target count.
      _displayedSteps = 0;
      _animatedProgress = 0;
      if (widget.state.lastDisplayedStepsLoaded) {
        _seedFromDisplayState();
        _scheduleAfterDisplayStateLoaded();
      }
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

    final displayDayChanged =
        oldWidget.state.selectedLocalDay != widget.state.selectedLocalDay;
    final displayStateBecameLoaded =
        !oldWidget.state.lastDisplayedStepsLoaded &&
        widget.state.lastDisplayedStepsLoaded;
    final displaySeedChanged =
        oldWidget.state.lastDisplayedSteps != widget.state.lastDisplayedSteps;

    if (displayDayChanged || displayStateBecameLoaded || displaySeedChanged) {
      _coldStartHandled = false;
      _displayStateHandled = false;
      if (widget.state.lastDisplayedStepsLoaded) {
        _seedFromDisplayState();
        _scheduleAfterDisplayStateLoaded();
      } else if (displayDayChanged) {
        _lastDisplayedSteps = 0;
        _displayedSteps = 0;
        _animatedProgress = 0;
      }
    }

    _handleStepChange(
      oldStatus: oldWidget.state.status,
      oldSteps: oldWidget.state.steps,
    );
  }

  void _seedFromDisplayState() {
    final seed = widget.state.lastDisplayedSteps ?? 0;
    _lastDisplayedSteps = seed;
    _displayedSteps = seed;
    _animatedProgress = _progressRatioFor(seed);
  }

  void _scheduleAfterDisplayStateLoaded() {
    if (_displayStateHandled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.state.lastDisplayedStepsLoaded ||
          _displayStateHandled) {
        return;
      }
      _displayStateHandled = true;
      _afterDisplayStateLoaded();
    });
  }

  void _afterDisplayStateLoaded() {
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
    if (!widget.state.lastDisplayedStepsLoaded) {
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

    livePipelineLog(
      'ring',
      'step target changed',
      details: {
        'displayed': _displayedSteps,
        'target': target,
        'stateSteps': widget.state.steps,
        'catchUp': widget.state.foregroundCatchUp,
        'status': widget.state.status.name,
      },
      minInterval: const Duration(milliseconds: 400),
    );

    if (target > _displayedSteps) {
      final delta = target - _displayedSteps;
      if (_countUpController?.isAnimating == true) {
        _pendingLiveSteps = target;
        return;
      }
      if (widget.state.foregroundCatchUp) {
        if (_foregroundCatchUpScheduled || _foregroundCatchUpTimer != null) {
          return;
        }
        final catchUpTarget =
            widget.state.catchUpTargetSteps ?? _targetSteps;
        if (catchUpTarget <= _displayedSteps) {
          widget.onForegroundCatchUpHandled?.call();
          return;
        }
        _foregroundCatchUpScheduled = true;
        _foregroundCatchUpTimer = Timer(kForegroundCatchUpDelay, () {
          _foregroundCatchUpTimer = null;
          _foregroundCatchUpScheduled = false;
          if (!mounted) {
            return;
          }
          final catchUpTarget = _targetSteps;
          if (catchUpTarget <= _displayedSteps) {
            widget.onForegroundCatchUpHandled?.call();
            return;
          }
          _pendingForegroundCatchUpClear = true;
          _runCountUp(
            from: _displayedSteps,
            to: catchUpTarget,
            coldStart: true,
          );
        });
        return;
      }
      if (useMicroTickForLiveDelta(delta)) {
        _scheduleLiveUpdate(target);
      } else {
        _runCountUp(from: _displayedSteps, to: target, coldStart: false);
      }
      return;
    }

    // Monotonic within the local day — SQLite can lag behind prefs on cold start.
    if (target < _displayedSteps) {
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
    _releaseCountUpController();
    _releaseMicroTickController();
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
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }
      _displayedSteps = to;
      _animatedProgress = toRatio;
      _lastDisplayedSteps = to;
      _notifyLastDisplayedStepsChanged(to);
      _releaseCountUpController();
      if (_pendingForegroundCatchUpClear) {
        _pendingForegroundCatchUpClear = false;
        widget.onForegroundCatchUpHandled?.call();
      }
      final pending = _pendingLiveSteps;
      if (pending != null && pending != to) {
        _pendingLiveSteps = null;
        _scheduleLiveUpdate(pending);
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
    final controller = _countUpController;
    if (controller == null) {
      return;
    }
    final t = Curves.easeInOut.transform(controller.value);
    setState(() {
      _displayedSteps = (_countUpFrom + (_countUpTo - _countUpFrom) * t).round();
      _animatedProgress =
          _countUpFromRatio + (_countUpToRatio - _countUpFromRatio) * t;
    });
  }

  void _runMicroTick({required int from, required int to}) {
    _releaseCountUpController();
    _releaseMicroTickController();
    _microTickPreviousSteps = from;
    _displayedSteps = to;
    _lastDisplayedSteps = to;

    _releaseLiveArcController();
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
        _notifyLastDisplayedStepsChanged(to);
      }
    }

    _microTickController!.addStatusListener(onMicroTickDone);
    _liveArcController!.forward();
    _microTickController!.forward();
  }

  void _setDisplayedInstant(int steps) {
    _releaseCountUpController();
    _releaseMicroTickController();
    _microTickPreviousSteps = null;
    _releaseLiveArcController();

    setState(() {
      _displayedSteps = steps;
      _animatedProgress = _progressRatioFor(steps);
      _lastDisplayedSteps = steps;
    });
    _notifyLastDisplayedStepsChanged(steps);
  }

  void _notifyLastDisplayedStepsChanged(int steps) {
    widget.onLastDisplayedStepsChanged?.call(steps);
  }

  void _resetDisplayed({required bool instant}) {
    _liveCoalesceTimer?.cancel();
    _foregroundCatchUpTimer?.cancel();
    _foregroundCatchUpTimer = null;
    _foregroundCatchUpScheduled = false;
    _pendingForegroundCatchUpClear = false;
    _pendingLiveSteps = null;
    if (instant) {
      _setDisplayedInstant(0);
    }
  }

  void _syncPulseAnimation() {
    final shouldPulse =
        _isLoadingPlaceholder &&
        widget.state.status != TodayStatus.noPermission;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (shouldPulse && !disableAnimations) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    } else {
      _releasePulseController();
    }
  }

  void _syncOverflowAnimation() {
    if (widget.freezeMotion) {
      _releaseOverflowController();
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
      _releaseOverflowController();
    }
  }

  int get _targetSteps {
    return switch (widget.state.status) {
      TodayStatus.loading => 0,
      TodayStatus.noPermission => 0,
      TodayStatus.empty => 0,
      _ => widget.state.foregroundCatchUp &&
              widget.state.catchUpTargetSteps != null
          ? widget.state.catchUpTargetSteps!
          : widget.state.steps,
    };
  }

  double get _targetProgressRatio => GoalRing.ringProgressFor(widget.state);

  bool get _isLoadingPlaceholder =>
      widget.state.status == TodayStatus.loading ||
      !widget.state.lastDisplayedStepsLoaded;

  double get _effectiveProgress {
    if (_isLoadingPlaceholder ||
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

  final _insetShadowCache = GoalRingInsetShadowCache();

  @override
  void dispose() {
    _liveCoalesceTimer?.cancel();
    _liveCoalesceTimer = null;
    _foregroundCatchUpTimer?.cancel();
    _foregroundCatchUpTimer = null;
    _releasePulseController();
    _releaseCountUpController();
    _releaseMicroTickController();
    _releaseLiveArcController();
    _releaseOverflowController();
    _insetShadowCache.dispose();
    assert(() {
      assert(_pulseController == null);
      assert(_countUpController == null);
      assert(_microTickController == null);
      assert(_liveArcController == null);
      assert(_overflowController == null);
      assert(_liveCoalesceTimer == null);
      assert(_foregroundCatchUpTimer == null);
      return true;
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = (constraints.maxWidth * kGoalRingWidthFactor).clamp(
            kGoalRingMinDiameter,
            kGoalRingMaxDiameter,
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
      ),
    );
  }

  Widget _buildRing(Size size, AstraColors colors, bool reduceMotion) {
    final status = widget.state.status;
    final devicePixelRatio = View.of(context).devicePixelRatio;
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
        strokeWidth: kGoalRingStrokeWidth,
        dashedTrack: status == TodayStatus.noPermission,
        shadowCache: status != TodayStatus.noPermission ? _insetShadowCache : null,
        devicePixelRatio: devicePixelRatio,
      ),
    );

    Widget result = ring;

    if (_isLoadingPlaceholder &&
        widget.state.status != TodayStatus.noPermission &&
        _pulseController != null) {
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
              strokeWidth: kGoalRingStrokeWidth,
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
    final showLoadingSkeleton =
        _isLoadingPlaceholder && status != TodayStatus.noPermission;

    final centerText = switch (status) {
      TodayStatus.loading => '',
      TodayStatus.noPermission => '--',
      TodayStatus.empty => formatStepCount(0),
      _ => null,
    };

    final stepCountStyle = AstraTypography.goalRingStepCountFor(colors);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Icon(
                  PhosphorIconsFill.sneakerMove,
                  size: 20,
                  color: colors.neutralGray,
                ),
              ),
              const SizedBox(width: AstraSpacing.kSpaceXs),
              Text('Steps', style: AstraTypography.goalRingLabelFor(colors)),
            ],
          ),
          if (showLoadingSkeleton)
            _GoalRingCenterSkeleton(
              key: const Key('goal_ring_loading_skeleton'),
              colors: colors,
              pulseController: reduceMotion ? null : _pulseController,
            )
          else ...[
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
              style: AstraTypography.goalRingLabelFor(colors),
            ),
          ],
        ],
      ),
    );
  }

  String get _semanticsLabel {
    if (_isLoadingPlaceholder &&
        widget.state.status != TodayStatus.noPermission) {
      return 'Steps today: loading';
    }
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
    if (_isLoadingPlaceholder &&
        widget.state.status != TodayStatus.noPermission) {
      return null;
    }
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

class _GoalRingCenterSkeleton extends StatelessWidget {
  const _GoalRingCenterSkeleton({
    super.key,
    required this.colors,
    this.pulseController,
  });

  final AstraColors colors;
  final AnimationController? pulseController;

  @override
  Widget build(BuildContext context) {
    Widget buildBars(double opacityScale) {
      Color barColor() =>
          colors.textMuted.withValues(alpha: 0.18 * opacityScale);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Container(
            width: 84,
            height: 28,
            decoration: BoxDecoration(
              color: barColor(),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 14,
            decoration: BoxDecoration(
              color: barColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    }

    final controller = pulseController;
    if (controller == null) {
      return buildBars(1);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final opacityScale = 0.35 + (0.85 - 0.35) * controller.value;
        return buildBars(opacityScale);
      },
    );
  }
}

class GoalRingPainter extends CustomPainter {
  GoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.dashedTrack,
    this.shadowCache,
    this.devicePixelRatio = 1.0,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  final bool dashedTrack;
  /// Nullable: null when [dashedTrack] is true (dashed track has no inset shadow).
  final GoalRingInsetShadowCache? shadowCache;
  final double devicePixelRatio;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final innerRadius = radius - strokeWidth / 2;
    final outerRadius = radius + strokeWidth / 2;

    if (dashedTrack) {
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      _drawDashedArc(canvas, rect, trackPaint, _startAngle, _fullSweep);
    } else {
      final annulus = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius));

      canvas.drawPath(annulus, Paint()..color = trackColor);
      if (shadowCache != null) {
        paintGoalRingTrackInnerShadow(
          canvas, annulus, center, innerRadius, outerRadius,
          size, devicePixelRatio, shadowCache!,
        );
      }
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
