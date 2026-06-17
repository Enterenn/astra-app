import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_inset_shadow.dart';

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
    this.enableHaptics = true,
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
  final bool enableHaptics;

  static const itemExtent = 10.0;
  static const minorTickHeight = 12.0;
  static const majorTickHeight = 24.0;
  static const centerIndicatorWidth = 2.0;
  static const centerIndicatorHeight = 32.0;
  static const rulerBandHeight = 56.0;
  static const snapDuration = Duration(milliseconds: 200);

  @override
  State<AstraHorizontalRuler> createState() => _AstraHorizontalRulerState();
}

class _AstraHorizontalRulerState extends State<AstraHorizontalRuler> {
  late ScrollController _scrollController;
  late double _displayValue;
  double? _lastReportedValue;
  bool _syncingScroll = false;

  int get _tickCount {
    if (widget.step <= 0 || widget.max < widget.min) return 1;
    return ((widget.max - widget.min) / widget.step).round() + 1;
  }

  @override
  void initState() {
    super.initState();
    _displayValue = _clampToStepGrid(widget.value);
    _lastReportedValue = _displayValue;
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollToValue(
          _displayValue,
          animate: false,
        ));
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
      _syncScrollToValue(clamped, animate: false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          .whenComplete(() => _syncingScroll = false);
    } else {
      _scrollController.jumpTo(targetOffset);
      _syncingScroll = false;
    }
  }

  void _updateDisplayFromScroll() {
    if (!_scrollController.hasClients) return;
    final index =
        (_scrollController.offset / AstraHorizontalRuler.itemExtent).round();
    final value = _valueForIndex(index);
    if (value != _displayValue) {
      setState(() => _displayValue = value);
    }
  }

  void _snapToNearestTick() {
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
        _finalizeValueChange(newValue);
      } else {
        _scrollController
            .animateTo(
              targetOffset,
              duration: AstraHorizontalRuler.snapDuration,
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
          _syncingScroll = false;
          _finalizeValueChange(newValue);
        });
      }
    } else {
      _finalizeValueChange(newValue);
    }
  }

  void _finalizeValueChange(double newValue) {
    if (_displayValue != newValue) {
      setState(() => _displayValue = newValue);
    }
    if (_lastReportedValue != newValue) {
      _lastReportedValue = newValue;
      widget.onChanged(newValue);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollMetricsNotification) {
      _updateDisplayFromScroll();
    }
    if (notification is ScrollEndNotification) {
      _snapToNearestTick();
    }
    return false;
  }

  bool _isMajorTick(double tickValue) {
    if (widget.majorTickEvery <= 0) return false;
    final offsetFromMin = tickValue - widget.min;
    final stepsFromMin = (offsetFromMin / widget.step).round();
    final majorEverySteps =
        (widget.majorTickEvery / widget.step).round().clamp(1, 999999);
    return stepsFromMin % majorEverySteps == 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return AstraInsetShadowSurface(
      color: colors.bgElevated,
      borderRadius: BorderRadius.circular(AstraSpacing.kRadiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kCardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatValue(_displayValue),
              style: AstraTypography.displayFor(colors),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            SizedBox(
              height: AstraHorizontalRuler.rulerBandHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sidePadding =
                      constraints.maxWidth / 2 -
                      AstraHorizontalRuler.itemExtent / 2;

                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: sidePadding),
                          itemExtent: AstraHorizontalRuler.itemExtent,
                          itemCount: _tickCount,
                          itemBuilder: (context, index) {
                            final tickValue = _valueForIndex(index);
                            final isMajor = _isMajorTick(tickValue);
                            return _RulerTick(
                              colors: colors,
                              isMajor: isMajor,
                              label: isMajor ? _formatValue(tickValue) : null,
                            );
                          },
                        ),
                      ),
                      IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: AstraHorizontalRuler.centerIndicatorWidth,
                              height:
                                  AstraHorizontalRuler.centerIndicatorHeight,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(height: AstraSpacing.kSpaceXs),
                            Text(
                              widget.unitLabel,
                              style: AstraTypography.captionFor(colors),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
  });

  final AstraColors colors;
  final bool isMajor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tickHeight = isMajor
        ? AstraHorizontalRuler.majorTickHeight
        : AstraHorizontalRuler.minorTickHeight;

    return SizedBox(
      width: AstraHorizontalRuler.itemExtent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 1,
            height: tickHeight,
            color: isMajor ? colors.textPrimary : colors.borderDefault,
          ),
          if (label != null) ...[
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(
              label!,
              style: AstraTypography.captionFor(colors),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ],
        ],
      ),
    );
  }
}
