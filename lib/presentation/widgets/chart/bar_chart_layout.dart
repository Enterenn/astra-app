/// Bar center X positions for space-around bar alignment.
///
/// Matches `BarChartDataExtension.calculateGroupsX` when every group shares
/// [barWidth].
List<double> computeSpaceAroundBarCenters({
  required double viewWidth,
  required int barCount,
  required double barWidth,
}) {
  if (barCount <= 0 || viewWidth <= 0) {
    return const [];
  }

  final sumWidth = barWidth * barCount;
  final spaceAvailable = viewWidth - sumWidth;
  final eachSpace = spaceAvailable / (barCount * 2);
  final centers = List<double>.filled(barCount, 0);
  var tempX = 0.0;

  for (var index = 0; index < barCount; index++) {
    tempX += eachSpace;
    tempX += barWidth / 2;
    centers[index] = tempX;
    tempX += barWidth / 2;
    tempX += eachSpace;
  }

  return centers;
}
