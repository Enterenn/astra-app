import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('LanguageSelector', () {
    Future<void> pumpSelector(
      WidgetTester tester, {
      String? explicitLanguageCode,
      ValueChanged<String>? onChanged,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: LanguageSelector(
              explicitLanguageCode: explicitLanguageCode,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tap French segment fires callback', (tester) async {
      String? changed;
      await pumpSelector(
        tester,
        onChanged: (code) => changed = code,
      );

      await tester.tap(find.text('French'));
      await tester.pump();

      expect(changed, 'fr');
    });
  });
}
