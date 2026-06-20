import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const kTestLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// MaterialApp pre-configured with Astra localization delegates for widget tests.
class TestMaterialApp extends MaterialApp {
  TestMaterialApp({
    super.key,
    required super.home,
    super.theme,
    super.darkTheme,
    super.themeMode,
    super.locale = const Locale('en'),
    super.navigatorKey,
    super.scaffoldMessengerKey,
    super.routes,
    super.onGenerateRoute,
    super.initialRoute,
    super.builder,
  }) : super(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

Future<void> pumpLocalizedWidget(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}
