import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('AboutScreen', () {
    Future<void> pumpAbout(
      WidgetTester tester, {
      required PackageInfo packageInfo,
    }) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: AboutScreen(
            packageInfoFuture: Future.value(packageInfo),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Astra Health title and version line', (tester) async {
      await pumpAbout(
        tester,
        packageInfo: PackageInfo(
          appName: 'astra_app',
          packageName: 'com.example.astra_app',
          version: '0.2.2',
          buildNumber: '5',
        ),
      );

      expect(find.text('Astra Health'), findsOneWidget);
      expect(find.text('Version: 0.2.2'), findsOneWidget);
      expect(find.textContaining('buildNumber'), findsNothing);
      expect(find.textContaining('(5)'), findsNothing);
    });

    testWidgets('shows About header from SecondaryScreenShell', (tester) async {
      await pumpAbout(
        tester,
        packageInfo: PackageInfo(
          appName: 'astra_app',
          packageName: 'com.example.astra_app',
          version: '0.2.2',
          buildNumber: '5',
        ),
      );

      expect(find.text('About'), findsOneWidget);
    });
  });
}
