import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/l10n/l10n_date_labels.dart';
import 'package:astra_app/presentation/widgets/trend_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../helpers/astra_theme_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('TrendChip', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required TrendSnapshot trend,
    }) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          TrendChip(trend: trend),
          preset: AstraAccentPreset.magenta,
        ),
      );
      await tester.pump();
    }

    testWidgets('renders up copy and positive color', (tester) async {
      const trend = TrendSnapshot(
        direction: TrendDirection.up,
        percent: 12,
      );

      await pumpChip(tester, trend: trend);

      expect(find.text(l10n.trendLabel(trend)), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowUp), findsOneWidget);
    });

    testWidgets('up and down trends use distinct preset-tinted colors', (
      tester,
    ) async {
      const preset = AstraAccentPreset.magenta;
      final colors = AstraColors.light(preset: preset);

      const upTrend = TrendSnapshot(
        direction: TrendDirection.up,
        percent: 5,
      );
      await pumpChip(tester, trend: upTrend);
      final upColor =
          tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.arrowUp)).color;

      const downTrend = TrendSnapshot(
        direction: TrendDirection.down,
        percent: 3,
      );
      await pumpChip(tester, trend: downTrend);
      final downColor =
          tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.arrowDown)).color;

      expect(upColor, colors.dataPositive);
      expect(downColor, colors.dataNegative);
      expect(upColor, isNot(equals(downColor)));
      expect(downColor!.a, lessThan(upColor!.a));
    });

    testWidgets('renders down copy and negative icon', (tester) async {
      const trend = TrendSnapshot(
        direction: TrendDirection.down,
        percent: 8,
      );

      await pumpChip(tester, trend: trend);

      expect(find.text(l10n.trendLabel(trend)), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowDown), findsOneWidget);
    });

    testWidgets('renders flat copy', (tester) async {
      const trend = TrendSnapshot(
        direction: TrendDirection.flat,
        percent: 0,
      );

      await pumpChip(tester, trend: trend);

      expect(find.text(l10n.trendLabel(trend)), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.minus), findsOneWidget);
    });
  });

  group('CaptionPill', () {
    testWidgets('renders label without leading icon', (tester) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          const CaptionPill(label: 'Jul 2025 – Jun 2026'),
          preset: AstraAccentPreset.magenta,
        ),
      );
      await tester.pump();

      expect(find.text('Jul 2025 – Jun 2026'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}
