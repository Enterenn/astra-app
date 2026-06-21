import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/l10n/l10n_date_labels.dart';
import 'package:astra_app/presentation/widgets/trends_peak_day_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpCard(
    WidgetTester tester, {
    required TrendsPeakDay peakDay,
    HistoryPeriod period = HistoryPeriod.days7,
  }) async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: TrendsPeakDayCard(
            peakDay: peakDay,
            period: period,
          ),
        ),
      ),
    );
  }

  group('TrendsPeakDayCard', () {
    testWidgets('renders date label, steps, and caption', (tester) async {
      const period = HistoryPeriod.days7;
      final peakDay = TrendsPeakDay(
        localDay: DateTime.utc(2026, 6, 4),
        totalSteps: 8500,
      );
      final dateLabel = l10n.formatPeakDayLabel(peakDay.localDay, period);

      await pumpCard(tester, peakDay: peakDay, period: period);

      expect(find.text(dateLabel), findsOneWidget);
      expect(find.text('8500'), findsOneWidget);
      expect(find.text(l10n.todayGoalRingStepsLabel), findsOneWidget);
      expect(find.text(l10n.trendsPeakDayCaption), findsOneWidget);
    });

    testWidgets('renders trophy icon', (tester) async {
      await pumpCard(
        tester,
        peakDay: TrendsPeakDay(
          localDay: DateTime.utc(2026, 6, 4),
          totalSteps: 5000,
        ),
      );

      expect(find.byIcon(PhosphorIconsRegular.trophy), findsOneWidget);
    });

    testWidgets('exposes semantics label for screen readers', (tester) async {
      const period = HistoryPeriod.days7;
      final peakDay = TrendsPeakDay(
        localDay: DateTime.utc(2026, 6, 4),
        totalSteps: 8500,
      );
      final dateLabel = l10n.formatPeakDayLabel(peakDay.localDay, period);
      final semanticsLabel = l10n.trendsPeakDaySemantics(
        dateLabel,
        peakDay.totalSteps,
      );

      await pumpCard(tester, peakDay: peakDay, period: period);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == semanticsLabel,
        ),
        findsOneWidget,
      );
    });
  });
}
