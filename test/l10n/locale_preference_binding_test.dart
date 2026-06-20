import 'package:astra_app/data/contracts/user_settings_repository_contract.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/locale_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/l10n_test_helper.dart';

class _LocaleSettingsFake implements UserSettingsRepositoryContract {
  String? stored;

  @override
  Future<String?> getAppLocale() async => stored;

  @override
  Future<void> setAppLocale(String languageCode) async {
    stored = languageCode;
  }

  @override
  bool get isDatabaseOpen => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Locale preference binding', () {
    testWidgets('applies seeded French locale on first frame', (tester) async {
      final settings = _LocaleSettingsFake();
      await settings.setAppLocale('fr');

      final localeCubit = LocaleCubit(
        userSettings: settings,
        initialLanguageCode: await settings.getAppLocale(),
      );
      addTearDown(localeCubit.close);

      await tester.pumpWidget(
        BlocProvider<LocaleCubit>(
          create: (_) => localeCubit,
          child: MaterialApp(
            locale: localeCubit.state.materialLocale,
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(l10n.settingsTitle);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });
  });
}
