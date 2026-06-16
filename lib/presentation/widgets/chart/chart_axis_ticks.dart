import 'dart:math' as math;

/// Computes readable Y-axis tick positions for bar charts.
///
/// Targets [targetTickCount] labels between 0 and [maxY], optionally merging
/// [referenceValues] (e.g. daily goal levels) when they are not too close to
/// an existing tick.
List<double> computeChartYAxisTicks({
  required double maxY,
  Iterable<int> referenceValues = const [],
  int targetTickCount = 5,
}) {
  if (maxY <= 0) {
    return const [0];
  }

  final step = _niceStep(maxY / math.max(targetTickCount - 1, 1));
  final ticks = <double>{0};

  var value = step;
  while (value < maxY - step * 0.08) {
    ticks.add(value);
    value += step;
  }
  ticks.add(maxY);

  final mergeThreshold = maxY * 0.08;
  for (final reference in referenceValues) {
    if (reference <= 0 || reference > maxY) {
      continue;
    }
    final tooClose = ticks.any(
      (tick) => (tick - reference).abs() < mergeThreshold,
    );
    if (!tooClose) {
      ticks.add(reference.toDouble());
    }
  }

  final sorted = ticks.toList()..sort();
  return sorted;
}

/// Returns the most frequent value in [values], breaking ties toward the first.
int mostCommonChartReferenceValue(Iterable<int> values) {
  final counts = <int, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts.entries
      .reduce(
        (best, entry) => entry.value > best.value ? entry : best,
      )
      .key;
}

/// Compact axis label: plain integer or `k` suffix when ≥ 1000.
String formatChartAxisValue(int value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    return thousands == thousands.roundToDouble()
        ? '${thousands.toInt()}k'
        : '${thousands.toStringAsFixed(1)}k';
  }
  return '$value';
}

/// Smallest positive gap between consecutive [ticks] for fl_chart `interval`.
double chartAxisTitleInterval(List<double> ticks) {
  if (ticks.length < 2) {
    return 1;
  }

  var minGap = ticks.last - ticks.first;
  for (var index = 1; index < ticks.length; index++) {
    final gap = ticks[index] - ticks[index - 1];
    if (gap > 0) {
      minGap = math.min(minGap, gap);
    }
  }
  return minGap <= 0 ? 1 : minGap;
}

/// Whether [value] from fl_chart should render the label for [tick].
bool isChartAxisTickLabel({
  required double value,
  required double tick,
  required List<double> ticks,
}) {
  final interval = chartAxisTitleInterval(ticks);
  return (value - tick).abs() <= interval * 0.15;
}

double _niceStep(double rawStep) {
  if (rawStep <= 0) {
    return 1;
  }

  final exponent = math.pow(10, (math.log(rawStep) / math.ln10).floor());
  final magnitude = exponent.toDouble();
  final normalized = rawStep / magnitude;

  final double niceNormalized;
  if (normalized <= 1) {
    niceNormalized = 1;
  } else if (normalized <= 2) {
    niceNormalized = 2;
  } else if (normalized <= 5) {
    niceNormalized = 5;
  } else {
    niceNormalized = 10;
  }

  return niceNormalized * magnitude;
}
