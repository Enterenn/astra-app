import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/sheet_drag_handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  testWidgets('renders canonical 32×4 handle with borderDefault color',
      (tester) async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: const Scaffold(body: SheetDragHandle()),
      ),
    );

    final containerFinder = find.descendant(
      of: find.byType(SheetDragHandle),
      matching: find.byType(Container),
    );

    expect(containerFinder, findsOneWidget);

    final size = tester.getSize(containerFinder);
    expect(size.width, 32);
    expect(size.height, 4);

    final container = tester.widget<Container>(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(2));
    expect(decoration.color, const Color(0xFFA0A0AA)); // AstraColors._neutralGray == borderDefault
  });
}
