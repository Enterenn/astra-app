import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/astra_theme.dart';
import 'core/di/app_dependencies.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'presentation/cubits/onboarding_cubit.dart';
import 'presentation/cubits/theme_cubit.dart';
import 'presentation/cubits/theme_state.dart';
import 'presentation/onboarding/onboarding_flow.dart';
import 'presentation/screens/app_scaffold.dart';

class AstraApp extends StatefulWidget {
  const AstraApp({
    super.key,
    required this.deps,
    this.createOnboardingCubit,
  });

  final AppDependencies deps;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
      createOnboardingCubit;

  @override
  State<AstraApp> createState() => _AstraAppState();
}

class _AstraAppState extends State<AstraApp> {
  late bool _showMainShell;

  @override
  void initState() {
    super.initState();
    _showMainShell = widget.deps.initialOnboardingComplete;
  }

  void _onOnboardingComplete() {
    setState(() {
      _showMainShell = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(initialPreference: widget.deps.initialTheme),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'ASTRA',
            theme: buildAstraLightTheme(),
            darkTheme: buildAstraDarkTheme(),
            themeMode: themeState.materialThemeMode,
            home: _showMainShell
                ? const AppScaffold()
                : OnboardingFlow(
                    deps: widget.deps,
                    onComplete: _onOnboardingComplete,
                    createCubit: widget.createOnboardingCubit,
                  ),
          );
        },
      ),
    );
  }
}
