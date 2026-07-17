import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/astra_colors.dart';
import '../../../core/constants/astra_typography.dart';
import 'astra_bar_chart_painter.dart';
import 'astra_bar_chart_touch.dart';
import 'astra_single_goal_line_painter.dart';
import 'chart_axis_ticks.dart';

/// Default width reserved for the left Y-axis column in chart layouts.
const kAstraBarChartLeftAxisReserved = 36.0;

/// Default height reserved for the bottom X-axis row in chart layouts.
const kAstraBarChartBottomAxisReserved = 24.0;

/// Shared native bar chart shell: axes as [Text], bars via [CustomPainter].
class AstraBarChartCore extends StatefulWidget {
  const AstraBarChartCore({
    required this.values,
    required this.maxY,
    required this.barWidth,
    required this.yTicks,
    required this.colors,
    required this.barColor,
    required this.bottomLabelBuilder,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    this.leftAxisReserved = kAstraBarChartLeftAxisReserved,
    this.bottomAxisReserved = kAstraBarChartBottomAxisReserved,
    this.shouldShowBottomLabel,
    this.tooltipTextBuilder,
    this.singleGoalValue,
    super.key,
  });

  final List<double> values;
  final double maxY;
  final double barWidth;
  final List<double> yTicks;
  final AstraColors colors;
  final Color Function(int index, bool isSelected) barColor;
  final String Function(int index) bottomLabelBuilder;
  final bool Function(int index)? shouldShowBottomLabel;
  final String Function(int index)? tooltipTextBuilder;
  final int? selectedIndex;
  final ValueChanged<int?> onSelectedIndexChanged;
  final double leftAxisReserved;
  final double bottomAxisReserved;

  /// When set, draws a horizontal dashed goal line at this Y value.
  final double? singleGoalValue;

  @override
  State<AstraBarChartCore> createState() => _AstraBarChartCoreState();
}

class _AstraBarChartCoreState extends State<AstraBarChartCore> {
  static const _kPlotFocusBorderWidth = 2.0;

  late final FocusNode _focusNode;
  int? _focusedIndex;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'AstraBarChartCore');
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AstraBarChartCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    final barCount = widget.values.length;
    if (_focusedIndex != null && barCount > 0 && _focusedIndex! >= barCount) {
      _focusedIndex = barCount - 1;
    } else if (barCount == 0) {
      _focusedIndex = null;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && widget.values.isNotEmpty) {
      setState(() {
        _focusedIndex ??= widget.selectedIndex ?? 0;
      });
      return;
    }
    setState(() {});
  }

  void _moveFocusedIndex(int delta) {
    final barCount = widget.values.length;
    if (barCount == 0) {
      return;
    }
    final current = _focusedIndex ?? widget.selectedIndex ?? 0;
    setState(() {
      _focusedIndex = (current + delta).clamp(0, barCount - 1);
    });
  }

  void _focusBarAt(int index) {
    final barCount = widget.values.length;
    if (barCount == 0) {
      return;
    }
    setState(() {
      _focusedIndex = index.clamp(0, barCount - 1);
    });
  }

  void _activateFocusedBar() {
    final index = _focusedIndex;
    if (index == null || index < 0 || index >= widget.values.length) {
      return;
    }
    widget.onSelectedIndexChanged(
      widget.selectedIndex == index ? null : index,
    );
  }

  void _clearSelection() {
    if (widget.selectedIndex != null) {
      widget.onSelectedIndexChanged(null);
    }
  }

  Map<ShortcutActivator, Intent> get _shortcuts {
    if (widget.values.isEmpty) {
      return const {};
    }
    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const _MoveFocusIntent(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): const _MoveFocusIntent(1),
      const SingleActivator(LogicalKeyboardKey.home): const _MoveFocusToStartIntent(),
      const SingleActivator(LogicalKeyboardKey.end): const _MoveFocusToEndIntent(),
      const SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const _ClearSelectionIntent(),
    };
  }

  Map<Type, Action<Intent>> get _actions => {
        _MoveFocusIntent: CallbackAction<_MoveFocusIntent>(
          onInvoke: (intent) {
            _moveFocusedIndex(intent.delta);
            return null;
          },
        ),
        _MoveFocusToStartIntent: CallbackAction<_MoveFocusToStartIntent>(
          onInvoke: (_) {
            _focusBarAt(0);
            return null;
          },
        ),
        _MoveFocusToEndIntent: CallbackAction<_MoveFocusToEndIntent>(
          onInvoke: (_) {
            _focusBarAt(widget.values.length - 1);
            return null;
          },
        ),
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activateFocusedBar();
            return null;
          },
        ),
        _ClearSelectionIntent: CallbackAction<_ClearSelectionIntent>(
          onInvoke: (_) {
            _clearSelection();
            return null;
          },
        ),
      };

  void _handleTapUp(TapUpDetails details, BoxConstraints plotConstraints) {
    final index = barIndexAtPlotX(
      localX: details.localPosition.dx,
      plotWidth: plotConstraints.maxWidth,
      barCount: widget.values.length,
      barWidth: widget.barWidth,
    );

    if (index == null) {
      widget.onSelectedIndexChanged(null);
      return;
    }

    widget.onSelectedIndexChanged(
      widget.selectedIndex == index ? null : index,
    );
  }

  void _handleTapOutside() {
    if (widget.selectedIndex != null) {
      widget.onSelectedIndexChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final yTicks = widget.yTicks;
    final barCount = widget.values.length;

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: widget.leftAxisReserved,
                child: _YAxisLabels(
                  yTicks: yTicks,
                  maxY: widget.maxY,
                  colors: colors,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, plotConstraints) {
                    final plotWidth = plotConstraints.maxWidth;
                    final plotHeight = plotConstraints.maxHeight;
                    final focusRingColor =
                        colors.borderDefault.withValues(alpha: 0.8);

                    return FocusableActionDetector(
                      focusNode: _focusNode,
                      autofocus: false,
                      shortcuts: _shortcuts,
                      actions: _actions,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) =>
                            _handleTapUp(details, plotConstraints),
                        onTapDown: (details) {
                          final index = barIndexAtPlotX(
                            localX: details.localPosition.dx,
                            plotWidth: plotWidth,
                            barCount: barCount,
                            barWidth: widget.barWidth,
                          );
                          if (index == null) {
                            _handleTapOutside();
                          }
                        },
                        child: DecoratedBox(
                          decoration: _focusNode.hasFocus
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: focusRingColor,
                                    width: _kPlotFocusBorderWidth,
                                  ),
                                )
                              : const BoxDecoration(),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size(plotWidth, plotHeight),
                                painter: AstraBarChartPainter(
                                  values: widget.values,
                                  maxY: widget.maxY,
                                  barWidth: widget.barWidth,
                                  barColor: widget.barColor,
                                  selectedIndex: widget.selectedIndex,
                                  focusedIndex: _focusNode.hasFocus
                                      ? _focusedIndex
                                      : null,
                                  focusRingColor: focusRingColor,
                                ),
                              ),
                              if (widget.singleGoalValue != null &&
                                  widget.singleGoalValue! > 0)
                                CustomPaint(
                                  size: Size(plotWidth, plotHeight),
                                  painter: AstraSingleGoalLinePainter(
                                    goalY: plotHeight *
                                        (1 -
                                            widget.singleGoalValue! /
                                                widget.maxY),
                                    color: colors.dataGoalLine,
                                  ),
                                ),
                              if (widget.selectedIndex != null &&
                                  widget.tooltipTextBuilder != null)
                                _BarTooltip(
                                  text: widget.tooltipTextBuilder!(
                                    widget.selectedIndex!,
                                  ),
                                  barCenterX: barCenterPlotX(
                                    index: widget.selectedIndex!,
                                    plotWidth: plotWidth,
                                    barCount: barCount,
                                    barWidth: widget.barWidth,
                                  ),
                                  barTopY: barTopPlotY(
                                    value: widget.values[widget.selectedIndex!],
                                    maxY: widget.maxY,
                                    plotHeight: plotHeight,
                                  ),
                                  plotWidth: plotWidth,
                                  colors: colors,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: widget.bottomAxisReserved,
          child: Row(
            children: [
              SizedBox(width: widget.leftAxisReserved),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        for (var index = 0; index < barCount; index++)
                          if (widget.shouldShowBottomLabel?.call(index) ??
                              true)
                            _BottomLabel(
                              label: widget.bottomLabelBuilder(index),
                              centerX: barCenterPlotX(
                                index: index,
                                plotWidth: constraints.maxWidth,
                                barCount: barCount,
                                barWidth: widget.barWidth,
                              ),
                              colors: colors,
                            ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoveFocusIntent extends Intent {
  const _MoveFocusIntent(this.delta);

  final int delta;
}

class _MoveFocusToStartIntent extends Intent {
  const _MoveFocusToStartIntent();
}

class _MoveFocusToEndIntent extends Intent {
  const _MoveFocusToEndIntent();
}

class _ClearSelectionIntent extends Intent {
  const _ClearSelectionIntent();
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.yTicks,
    required this.maxY,
    required this.colors,
  });

  final List<double> yTicks;
  final double maxY;
  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final tick in yTicks)
              Positioned(
                left: 0,
                right: 0,
                top: _tickTop(tick, height) - 8,
                child: Text(
                  formatChartAxisValue(tick.round()),
                  style: AstraTypography.captionFor(colors).copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        );
      },
    );
  }

  double _tickTop(double tick, double height) {
    if (maxY <= 0) {
      return height;
    }
    return height * (1 - tick / maxY);
  }
}

class _BottomLabel extends StatelessWidget {
  const _BottomLabel({
    required this.label,
    required this.centerX,
    required this.colors,
  });

  final String label;
  final double centerX;
  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: centerX - 20,
      width: 40,
      top: 4,
      child: Text(
        label,
        style: AstraTypography.captionFor(colors).copyWith(
          color: colors.textPrimary,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

class _BarTooltip extends StatelessWidget {
  const _BarTooltip({
    required this.text,
    required this.barCenterX,
    required this.barTopY,
    required this.plotWidth,
    required this.colors,
  });

  final String text;
  final double barCenterX;
  final double barTopY;
  final double plotWidth;
  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    const maxWidth = 150.0;
    const tooltipHeight = 48.0;
    final left = (barCenterX - maxWidth / 2).clamp(0.0, plotWidth - maxWidth);
    final top = (barTopY - tooltipHeight - kAstraBarTooltipMargin)
        .clamp(0.0, double.infinity);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          padding: kAstraBarTooltipPadding,
          decoration: astraBarTooltipDecoration(colors),
          child: Text(
            text,
            style: astraBarTooltipPrimaryStyle(colors),
          ),
        ),
      ),
    );
  }
}

/// Resolves bar width from plot width and bar count (shared clamp logic).
double resolveAstraBarWidth({
  required double chartWidth,
  required int pointCount,
  double maxBarWidth = 12,
  double minBarWidth = 4,
  double slotFillRatio = 0.55,
}) {
  if (pointCount <= 0 || chartWidth <= 0) {
    return maxBarWidth;
  }
  final slotWidth = chartWidth / pointCount;
  return (slotWidth * slotFillRatio).clamp(minBarWidth, maxBarWidth);
}

/// Throttles 30d bottom labels: show every Nth label plus the last.
bool shouldShowThrottledBottomLabel(int index, int pointCount) {
  if (pointCount <= 7) {
    return true;
  }
  final step = (pointCount / 6).ceil().clamp(1, pointCount);
  return index % step == 0 || index == pointCount - 1;
}
