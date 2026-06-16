import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/astra_colors.dart';
import '../../../core/constants/astra_typography.dart';

/// Shared touch handling for Trends bar charts (fl_chart 1.2.x).
BarTouchData buildAstraBarTouchData({
  required AstraColors colors,
  required int? touchedIndex,
  required ValueChanged<int?> onTouchedIndexChanged,
  required BarTouchTooltipData tooltipData,
}) {
  return BarTouchData(
    enabled: true,
    handleBuiltInTouches: false,
    touchTooltipData: tooltipData,
    touchCallback: (event, response) {
      if (event is FlTapUpEvent || event is FlLongPressEnd) {
        final spot = response?.spot;
        if (spot == null) {
          onTouchedIndexChanged(null);
          return;
        }
        final index = spot.touchedBarGroupIndex;
        onTouchedIndexChanged(touchedIndex == index ? null : index);
        return;
      }

      if (!event.isInterestedForInteractions) {
        onTouchedIndexChanged(null);
      }
    },
  );
}

BarTouchTooltipData buildAstraBarTooltipData({
  required AstraColors colors,
  required BarTooltipItem? Function(
    BarChartGroupData group,
    int groupIndex,
    BarChartRodData rod,
    int rodIndex,
  ) getTooltipItem,
}) {
  return BarTouchTooltipData(
    maxContentWidth: 150,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tooltipMargin: 8,
    getTooltipColor: (_) => colors.bgElevated,
    getTooltipItem: getTooltipItem,
  );
}

TextStyle astraBarTooltipPrimaryStyle(AstraColors colors) {
  return AstraTypography.captionFor(colors).copyWith(
    color: colors.textPrimary,
    fontWeight: FontWeight.w600,
  );
}

List<BarChartGroupData> withBarTouchIndicators({
  required List<BarChartGroupData> groups,
  required int? touchedIndex,
}) {
  return [
    for (var index = 0; index < groups.length; index++)
      groups[index].copyWith(
        showingTooltipIndicators: touchedIndex == index ? const [0] : const [],
      ),
  ];
}
