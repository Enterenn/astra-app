import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'animated_step_count.dart';
import 'ruler_tick_scroll_physics.dart';

typedef RulerValueFormatter = String Function(double value);

/// Horizontal scroll picker with snap-to-tick behavior (UX-DR27).
class AstraHorizontalRuler extends StatefulWidget {
  const AstraHorizontalRuler({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
    required this.unitLabel,
    this.majorTickEvery = 10,
    this.valueFormatter,
    this.sliderVerticalMargin = 0,
    this.unitLabelGap = AstraSpacing.kSpaceXs,
    this.centerIndicatorHeight = 32,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String unitLabel;
  final double majorTickEvery;
  final RulerValueFormatter? valueFormatter;

  /// Vertical inset above and below the tick band (onboarding: 48px).
  final double sliderVerticalMargin;

  /// Space between tick band and unit label below (onboarding: 16px).
  final double unitLabelGap;

  /// Height of the center selection indicator bar (onboarding: 48px).
  final double centerIndicatorHeight;

  static const itemExtent = 10.0;
  static const labelRowHeight = 18.0;
  static const majorLabelMaxWidth = 44.0;
  static const minorTickHeight = 12.0;
  static const majorTickHeight = 24.0;
  static const centerIndicatorWidth = 2.0;
  static const selectedValueGap = 4.0;
  static const majorLabelGap = AstraSpacing.kSpaceSm;
  static const rulerBandHeight =
      majorTickHeight + majorLabelGap + labelRowHeight;
  static const snapDuration = Duration(milliseconds: 200);
  /// Matches goal-ring micro-tick duration for digit readout.
  static const readoutMicroTickMs = 150;
  static const indicatorPulseDuration = Duration(milliseconds: 180);
  static const scrollingLabelOpacity = 0.45;

  @override
  State<AstraHorizontalRuler> createState() => _AstraHorizontalRulerState();
}

class _AstraHorizontalRulerState extends State<AstraHorizontalRuler>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  AnimationController? _readoutMicroTickController;
  late double _displayValue;
  double? _lastReportedValue;
  int? _readoutPreviousInt;
  bool _syncingScroll = false;
  bool _isUserDrivingScroll = false;

  int get _tickCount {
    if (widget.step <= 0 || widget.max < widget.min) return 1;
    return ((widget.max - widget.min) / widget.step).round() + 1;
  }

  int get _centerIndex => _indexForValue(_displayValue);

  int get _readoutInt => _displayValue.round();

  bool get _usesDigitReadoutAnimation =>
      widget.valueFormatter == null &&
      widget.step >= 1 &&
      widget.step == widget.step.roundToDouble();

  @override
  void initState() {
    super.initState();
    assert(widget.step > 0, 'step must be positive');
    assert(widget.max >= widget.min, 'max must be >= min');
    _displayValue = _clampToStepGrid(widget.value);
    _lastReportedValue = _displayValue;
    _scrollController = ScrollController()..addListener(_handleScrollOffsetChange);
    _pulseController = AnimationController(
      vsync: this,
      duration: AstraHorizontalRuler.indicatorPulseDuration,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 45,
      ),
    ]).animate(_pulseController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScrollToValue(_displayValue, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant AstraHorizontalRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.step != widget.step) {
      final clamped = _clampToStepGrid(widget.value);
      _displayValue = clamped;
      _lastReportedValue = clamped;
      _releaseReadoutMicroTick();
      _syncScrollToValue(clamped, animate: false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollOffsetChange);
    _scrollController.dispose();
    _pulseController.dispose();
    _releaseReadoutMicroTick();
    super.dispose();
  }

  void _releaseReadoutMicroTick() {
    _readoutMicroTickController?.dispose();
    _readoutMicroTickController = null;
    _readoutPreviousInt = null;
  }

  int _tickIndexFromOffset([double? offset]) {
    if (!_scrollController.hasClients && offset == null) return 0;
    final pixels = offset ?? _scrollController.offset;
    return (pixels / AstraHorizontalRuler.itemExtent)
        .round()
        .clamp(0, _tickCount - 1);
  }

  void _runReadoutMicroTick({required int from, required int to}) {
    if (!_usesDigitReadoutAnimation || from == to) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    _releaseReadoutMicroTick();
    _readoutPreviousInt = from;
    _readoutMicroTickController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: AstraHorizontalRuler.readoutMicroTickMs,
      ),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _readoutPreviousInt = null);
        }
      })
      ..forward();
  }

  void _applyDisplayValue(
    double value, {
    required bool animateReadout,
    required bool pulseIndicator,
  }) {
    if (!mounted || value == _displayValue) return;

    final from = _readoutInt;
    final to = value.round();
    if (animateReadout && _usesDigitReadoutAnimation && from != to) {
      _runReadoutMicroTick(from: from, to: to);
    }
    if (pulseIndicator) {
      _pulseIndicator();
    }
    setState(() => _displayValue = value);
  }

  double _clampToStepGrid(double value) {
    final clamped = value.clamp(widget.min, widget.max);
    final index = ((clamped - widget.min) / widget.step).round();
    final safeIndex = index.clamp(0, _tickCount - 1);
    return widget.min + safeIndex * widget.step;
  }

  int _indexForValue(double value) {
    final clamped = _clampToStepGrid(value);
    return ((clamped - widget.min) / widget.step).round().clamp(0, _tickCount - 1);
  }

  double _valueForIndex(int index) {
    final safeIndex = index.clamp(0, _tickCount - 1);
    return widget.min + safeIndex * widget.step;
  }

  String _formatValue(double value) {
    if (widget.valueFormatter != null) {
      return widget.valueFormatter!(value);
    }
    if (widget.step >= 1 && widget.step == widget.step.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String get _semanticsLabel =>
      '${_formatValue(_displayValue)} ${widget.unitLabel}';

  String? get _semanticsIncreasedValue {
    final nextIndex = _indexForValue(_displayValue) + 1;
    if (nextIndex >= _tickCount) return null;
    return _formatValue(_valueForIndex(nextIndex));
  }

  String? get _semanticsDecreasedValue {
    final prevIndex = _indexForValue(_displayValue) - 1;
    if (prevIndex < 0) return null;
    return _formatValue(_valueForIndex(prevIndex));
  }

  void _stepBy(int direction) {
    final currentIndex = _indexForValue(_displayValue);
    final newIndex = (currentIndex + direction).clamp(0, _tickCount - 1);
    if (newIndex == currentIndex) return;
    _selectValue(_valueForIndex(newIndex), animate: true);
  }

  void _selectValue(double value, {required bool animate}) {
    final snapped = _clampToStepGrid(value);
    if (!_scrollController.hasClients) {
      _finalizeValueChange(snapped, fromUserGesture: false);
      return;
    }

    final targetOffset =
        _indexForValue(snapped) * AstraHorizontalRuler.itemExtent;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(targetOffset);
      _syncingScroll = false;
      _finalizeValueChange(snapped, fromUserGesture: false);
      return;
    }

    if ((_scrollController.offset - targetOffset).abs() < 0.5) {
      _finalizeValueChange(snapped, fromUserGesture: false);
      return;
    }

    _syncingScroll = true;
    _scrollController
        .animateTo(
          targetOffset,
          duration: AstraHorizontalRuler.snapDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      if (!mounted) return;
      _syncingScroll = false;
      _finalizeValueChange(snapped, fromUserGesture: false);
    });
  }

  void _syncScrollToValue(double value, {required bool animate}) {
    if (!_scrollController.hasClients) return;
    final index = _indexForValue(value);
    final targetOffset = index * AstraHorizontalRuler.itemExtent;
    if ((_scrollController.offset - targetOffset).abs() < 0.5) return;

    _syncingScroll = true;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _scrollController
          .animateTo(
            targetOffset,
            duration: AstraHorizontalRuler.snapDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
        if (!mounted) return;
        _syncingScroll = false;
      });
    } else {
      _scrollController.jumpTo(targetOffset);
      _syncingScroll = false;
    }
  }

  void _handleScrollOffsetChange() {
    if (!_scrollController.hasClients || _syncingScroll) return;

    final index = _tickIndexFromOffset();
    final value = _valueForIndex(index);

    if (value != _displayValue) {
      _applyDisplayValue(
        value,
        animateReadout: true,
        pulseIndicator: _isUserDrivingScroll,
      );
    }
  }

  void _pulseIndicator() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pulseController.forward(from: 0);
  }

  void _finalizeValueChange(double newValue, {required bool fromUserGesture}) {
    if (!mounted) return;
    if (_displayValue != newValue) {
      _applyDisplayValue(
        newValue,
        animateReadout: !fromUserGesture,
        pulseIndicator: !fromUserGesture,
      );
    }
    if (_lastReportedValue != newValue) {
      _lastReportedValue = newValue;
      widget.onChanged(newValue);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _isUserDrivingScroll = true;
    } else if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isUserDrivingScroll = true;
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) {
        _isUserDrivingScroll = true;
      }
    } else if (notification is ScrollEndNotification) {
      final wasDriving = _isUserDrivingScroll;
      _isUserDrivingScroll = false;
      _snapToNearestTick(fromUserGesture: wasDriving);
    }
    return false;
  }

  void _snapToNearestTick({required bool fromUserGesture}) {
    if (!_scrollController.hasClients || _syncingScroll) return;

    final index =
        (_scrollController.offset / AstraHorizontalRuler.itemExtent).round();
    final snappedIndex = index.clamp(0, _tickCount - 1);
    final newValue = _valueForIndex(snappedIndex);
    final targetOffset = snappedIndex * AstraHorizontalRuler.itemExtent;

    if ((_scrollController.offset - targetOffset).abs() > 0.5) {
      _syncingScroll = true;
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      if (disableAnimations) {
        _scrollController.jumpTo(targetOffset);
        _syncingScroll = false;
        _finalizeValueChange(newValue, fromUserGesture: fromUserGesture);
      } else {
        _scrollController
            .animateTo(
              targetOffset,
              duration: AstraHorizontalRuler.snapDuration,
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
          if (!mounted) return;
          _syncingScroll = false;
          _finalizeValueChange(newValue, fromUserGesture: fromUserGesture);
        });
      }
    } else {
      _finalizeValueChange(newValue, fromUserGesture: fromUserGesture);
    }
  }

  bool _isMajorTick(double tickValue) {
    if (widget.majorTickEvery <= 0) return false;
    final offsetFromMin = tickValue - widget.min;
    final stepsFromMin = (offsetFromMin / widget.step).round();
    final majorEverySteps =
        (widget.majorTickEvery / widget.step).round().clamp(1, 999999);
    return stepsFromMin % majorEverySteps == 0;
  }

  double _tickOpacityForIndex(int index) {
    final distance = (index - _centerIndex).abs();
    if (distance == 0) return 1;
    if (distance <= 2) return 0.6;
    return 0.38;
  }

  static double stackHeightFor(double indicatorHeight) {
    final tickZoneHeight = math.max(
      indicatorHeight,
      AstraHorizontalRuler.majorTickHeight,
    );
    return 80.0 +
        AstraHorizontalRuler.selectedValueGap +
        tickZoneHeight +
        AstraHorizontalRuler.majorLabelGap +
        AstraHorizontalRuler.labelRowHeight;
  }

  static double get _labelsBandHeight =>
      AstraHorizontalRuler.majorLabelGap + AstraHorizontalRuler.labelRowHeight;

  Widget _buildReadout(AstraColors colors) {
    final style = AstraTypography.rulerSelectedValueFor(colors);

    if (!_usesDigitReadoutAnimation ||
        MediaQuery.disableAnimationsOf(context)) {
      return Text(
        _formatValue(_displayValue),
        style: style,
        textAlign: TextAlign.center,
      );
    }

    return AnimatedStepCount(
      value: _readoutInt,
      previousValue: _readoutPreviousInt,
      microTickProgress: _readoutMicroTickController?.value ?? 0,
      style: style,
    );
  }

  Widget _buildCenterIndicator(AstraColors colors, double indicatorHeight) {
    final bar = Container(
      width: AstraHorizontalRuler.centerIndicatorWidth,
      height: indicatorHeight,
      color: colors.textPrimary,
    );

    if (MediaQuery.disableAnimationsOf(context)) return bar;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scaleX: _pulseScale.value,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: bar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final indicatorHeight = widget.centerIndicatorHeight;
    final stackHeight = stackHeightFor(indicatorHeight);
    final tickZoneHeight = math.max(
      indicatorHeight,
      AstraHorizontalRuler.majorTickHeight,
    );
    final marginTop = widget.sliderVerticalMargin;
    final marginBottom = widget.sliderVerticalMargin;
    final labelOpacity = _isUserDrivingScroll
        ? AstraHorizontalRuler.scrollingLabelOpacity
        : 1.0;

    final rulerBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (marginTop > 0) SizedBox(height: marginTop),
        SizedBox(
          height: stackHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidePadding =
                  constraints.maxWidth / 2 -
                  AstraHorizontalRuler.itemExtent / 2;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: AstraHorizontalRuler.rulerBandHeight,
                    child: Listener(
                      onPointerDown: (_) {
                        _isUserDrivingScroll = true;
                        if (mounted) setState(() {});
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        physics: RulerTickScrollPhysics(
                          itemExtent: AstraHorizontalRuler.itemExtent,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: sidePadding,
                        ),
                        itemExtent: AstraHorizontalRuler.itemExtent,
                        itemCount: _tickCount,
                        itemBuilder: (context, index) {
                          final tickValue = _valueForIndex(index);
                          final isMajor = _isMajorTick(tickValue);
                          return _RulerTick(
                            colors: colors,
                            isMajor: isMajor,
                            label: isMajor ? _formatValue(tickValue) : null,
                            tickOpacity: _tickOpacityForIndex(index),
                            labelOpacity: labelOpacity,
                            onLabelTap: isMajor
                                ? () {
                                    _selectValue(
                                      tickValue,
                                      animate: true,
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _labelsBandHeight,
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Center(
                          child: _buildCenterIndicator(
                            colors,
                            indicatorHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        _labelsBandHeight +
                        tickZoneHeight +
                        AstraHorizontalRuler.selectedValueGap,
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Center(child: _buildReadout(colors)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: widget.unitLabelGap),
        ExcludeSemantics(
          child: Text(
            widget.unitLabel,
            style: AstraTypography.captionFor(colors),
            textAlign: TextAlign.center,
          ),
        ),
        if (marginBottom > 0) SizedBox(height: marginBottom),
      ],
    );

    return Semantics(
      label: _semanticsLabel,
      value: _formatValue(_displayValue),
      increasedValue: _semanticsIncreasedValue,
      decreasedValue: _semanticsDecreasedValue,
      onIncrease:
          _semanticsIncreasedValue != null ? () => _stepBy(1) : null,
      onDecrease:
          _semanticsDecreasedValue != null ? () => _stepBy(-1) : null,
      slider: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AstraSpacing.kCardPadding),
          child: rulerBody,
        ),
      ),
    );
  }
}

class _RulerTick extends StatelessWidget {
  const _RulerTick({
    required this.colors,
    required this.isMajor,
    this.label,
    this.tickOpacity = 1,
    this.labelOpacity = 1,
    this.onLabelTap,
  });

  final AstraColors colors;
  final bool isMajor;
  final String? label;
  final double tickOpacity;
  final double labelOpacity;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final tickHeight = isMajor
        ? AstraHorizontalRuler.majorTickHeight
        : AstraHorizontalRuler.minorTickHeight;
    final tickColor = isMajor ? colors.textPrimary : colors.borderDefault;

    return SizedBox(
      width: AstraHorizontalRuler.itemExtent,
      height: AstraHorizontalRuler.rulerBandHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: AstraHorizontalRuler.majorTickHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: tickOpacity,
                child: Container(
                  width: 1,
                  height: tickHeight,
                  color: tickColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: AstraHorizontalRuler.majorLabelGap),
          SizedBox(
            height: AstraHorizontalRuler.labelRowHeight,
            child: label == null
                ? const SizedBox.shrink()
                : OverflowBox(
                    maxWidth: AstraHorizontalRuler.majorLabelMaxWidth,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: onLabelTap,
                      behavior: HitTestBehavior.translucent,
                      child: SizedBox(
                        width: AstraHorizontalRuler.majorLabelMaxWidth,
                        height: AstraHorizontalRuler.labelRowHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: labelOpacity,
                          child: Text(
                            label!,
                            style: AstraTypography.captionFor(colors),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
