import 'dart:ui' show Tristate;

import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/l10n/display_unit_l10n.dart';
import 'package:astra_app/presentation/widgets/unit_option_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('semantics', () {
    Future<void> openDistanceSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              final sheetL10n = AppLocalizations.of(context);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await showUnitOptionPickerSheet<DistanceDisplayUnit>(
                      context: context,
                      title: 'Distance',
                      options: DistanceDisplayUnit.values,
                      labelFor: (unit) =>
                          localizedDistanceUnitPreferenceLabel(sheetL10n, unit),
                      selected: DistanceDisplayUnit.metric,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('each distance option is a button with localized label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openDistanceSheet(tester);

      expect(
        find.bySemanticsLabel(l10n.unitDistanceMetric),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.unitDistanceImperial),
        findsOneWidget,
      );

      final metric = tester.getSemantics(
        find.bySemanticsLabel(l10n.unitDistanceMetric),
      );
      expect(metric.flagsCollection.isButton, isTrue);

      final imperial = tester.getSemantics(
        find.bySemanticsLabel(l10n.unitDistanceImperial),
      );
      expect(imperial.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('selected option reports selected semantics state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openDistanceSheet(tester);

      final metric = tester.getSemantics(
        find.bySemanticsLabel(l10n.unitDistanceMetric),
      );
      expect(metric.flagsCollection.isSelected, Tristate.isTrue);

      final imperial = tester.getSemantics(
        find.bySemanticsLabel(l10n.unitDistanceImperial),
      );
      expect(imperial.flagsCollection.isSelected, Tristate.isFalse);

      handle.dispose();
    });

    testWidgets('tap by semantics label selects and pops sheet', (tester) async {
      DistanceDisplayUnit? result;
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              final sheetL10n = AppLocalizations.of(context);
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result =
                        await showUnitOptionPickerSheet<DistanceDisplayUnit>(
                      context: context,
                      title: 'Distance',
                      options: DistanceDisplayUnit.values,
                      labelFor: (unit) =>
                          localizedDistanceUnitPreferenceLabel(sheetL10n, unit),
                      selected: DistanceDisplayUnit.metric,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.unitDistanceImperial));
      await tester.pumpAndSettle();

      expect(result, DistanceDisplayUnit.imperial);
      handle.dispose();
    });
  });

  testWidgets('showUnitOptionPickerSheet returns selected distance unit', (
    tester,
  ) async {
    DistanceDisplayUnit? result;

    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
                    context: context,
                    title: 'Distance',
                    options: DistanceDisplayUnit.values,
                    labelFor: (unit) => unit.displayLabel,
                    selected: DistanceDisplayUnit.metric,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Imperial'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.check), findsOneWidget);
    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();

    expect(result, DistanceDisplayUnit.imperial);
  });
}
