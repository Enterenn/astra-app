import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Locale _resolveLocale(Locale? locale, Iterable<Locale> supportedLocales) {
  if (locale != null) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('en');
}

void main() {
  testWidgets('resolves AppLocalizations for en and fr', (tester) async {
    AppLocalizations? englishLocalizations;
    AppLocalizations? frenchLocalizations;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            englishLocalizations = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(englishLocalizations, isNotNull);
    expect(englishLocalizations!.appTitle, 'ASTRA');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            frenchLocalizations = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(frenchLocalizations, isNotNull);
    expect(frenchLocalizations!.appTitle, 'ASTRA');
  });

  testWidgets('falls back to en for unsupported locale', (tester) async {
    AppLocalizations? localizations;
    Locale? resolvedLocale;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de', 'DE'),
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: _resolveLocale,
        home: Builder(
          builder: (context) {
            localizations = AppLocalizations.of(context);
            resolvedLocale = Localizations.localeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resolvedLocale, const Locale('en'));
    expect(localizations, isNotNull);
    expect(localizations!.localeName, 'en');
    expect(localizations!.appTitle, 'ASTRA');
  });
}
