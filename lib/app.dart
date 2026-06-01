import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/screens/app_scaffold.dart';

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'ASTRA',
            theme: buildAstraLightTheme(),
            darkTheme: buildAstraDarkTheme(),
            themeMode: themeState.materialThemeMode,
            home: const AppScaffold(),
          );
        },
      ),
    );
  }
}
