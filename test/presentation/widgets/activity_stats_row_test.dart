import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/activity_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required ThemeData theme,
    required TodayStatus status,
    ActivityMetricsSnapshot metrics = ActivityMetricsSnapshot.zero,
    DistanceDisplayUnit distanceDisplayUnit = DistanceDisplayUnit.metric,
  }) async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: theme,
        home: Scaffold(
          body: ActivityStatsRow(
            status: status,
            metrics: metrics,
            distanceDisplayUnit: distanceDisplayUnit,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows loading placeholders', (tester) async {
    await pumpRow(
      tester,
      theme: buildAstraLightTheme(),
      status: TodayStatus.loading,
    );

    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('shows zeros for noPermission', (tester) async {
    await pumpRow(
      tester,
      theme: buildAstraLightTheme(),
      status: TodayStatus.noPermission,
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
  });

  testWidgets('shows formatted metrics with accent primary dividers', (
    tester,
  ) async {
    await pumpRow(
      tester,
      theme: buildAstraLightTheme(),
      status: TodayStatus.progress,
      metrics: const ActivityMetricsSnapshot(
        distanceKm: 4.24,
        walkingDuration: Duration(minutes: 37, seconds: 20),
        kcal: 187,
      ),
    );

    expect(find.text('187'), findsOneWidget);
    expect(find.text('Kcal'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('Km'), findsOneWidget);
    expect(find.text('00:37:20'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
    expect(find.byIcon(PhosphorIconsRegular.fire), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.mapPin), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.clock), findsOneWidget);
  });

  testWidgets('zero activity day shows zeros not dashes', (tester) async {
    await pumpRow(
      tester,
      theme: buildAstraLightTheme(),
      status: TodayStatus.empty,
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('renders in dark theme', (tester) async {
    await pumpRow(
      tester,
      theme: buildAstraDarkTheme(),
      status: TodayStatus.progress,
      metrics: const ActivityMetricsSnapshot(
        distanceKm: 4.2,
        walkingDuration: Duration(minutes: 37, seconds: 20),
        kcal: 420,
      ),
    );

    expect(find.byType(ActivityStatsRow), findsOneWidget);
    expect(find.text('00:37:20'), findsOneWidget);
  });

  testWidgets('shows imperial distance when distanceDisplayUnit is imperial', (
    tester,
  ) async {
    await pumpRow(
      tester,
      theme: buildAstraLightTheme(),
      status: TodayStatus.progress,
      metrics: const ActivityMetricsSnapshot(
        distanceKm: 10,
        walkingDuration: Duration.zero,
        kcal: 0,
      ),
      distanceDisplayUnit: DistanceDisplayUnit.imperial,
    );

    expect(find.text('6.2'), findsOneWidget);
    expect(find.text('Mi'), findsOneWidget);
    expect(find.text('Km'), findsNothing);
  });
}
