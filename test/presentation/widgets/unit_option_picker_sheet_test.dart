import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/presentation/widgets/unit_option_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

void main() {
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
