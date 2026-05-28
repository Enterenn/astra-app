import 'package:astra_app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AstraApp shows theme preview screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AstraApp());
    expect(find.text('ASTRA Theme Preview'), findsOneWidget);
  });
}
