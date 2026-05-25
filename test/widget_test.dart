import 'package:astra_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders Hello World', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
