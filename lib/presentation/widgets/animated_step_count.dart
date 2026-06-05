import 'package:flutter/material.dart';

import '../formatters/step_count_formatter.dart';

/// Displays a step count with optional per-digit micro-tick on live updates.
class AnimatedStepCount extends StatelessWidget {
  const AnimatedStepCount({
    required this.value,
    required this.style,
    this.previousValue,
    this.microTickProgress = 0,
    super.key,
  });

  final int value;
  final int? previousValue;
  final double microTickProgress;
  final TextStyle style;

  @visibleForTesting
  static const microTickSlidePx = 5.0;

  @override
  Widget build(BuildContext context) {
    if (previousValue == null ||
        previousValue == value ||
        microTickProgress <= 0) {
      return Text(formatStepCount(value), style: style);
    }

    final currentSegments = stepCountSegments(value);
    final previousSegments = stepCountSegments(previousValue!);
    final maxLen = mathMax(currentSegments.length, previousSegments.length);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (var index = 0; index < maxLen; index++)
          _DigitCell(
            current: index < currentSegments.length
                ? currentSegments[index]
                : '',
            previous: index < previousSegments.length
                ? previousSegments[index]
                : '',
            progress: microTickProgress,
            style: style,
          ),
      ],
    );
  }

  static int mathMax(int a, int b) => a > b ? a : b;
}

class _DigitCell extends StatelessWidget {
  const _DigitCell({
    required this.current,
    required this.previous,
    required this.progress,
    required this.style,
  });

  final String current;
  final String previous;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (current == previous || current.isEmpty) {
      return Text(current, style: style);
    }

    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final offset = AnimatedStepCount.microTickSlidePx * (1 - eased);

    return ClipRect(
      child: SizedBox(
        height: (style.fontSize ?? 16) * (style.height ?? 1.2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -offset),
              child: Opacity(
                opacity: 1 - eased,
                child: Text(previous, style: style),
              ),
            ),
            Transform.translate(
              offset: Offset(0, offset),
              child: Opacity(
                opacity: eased,
                child: Text(current, style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
