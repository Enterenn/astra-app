import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/user_preferences_repository.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({
    required this.userPreferences,
    AstraThemePreference initialPreference = AstraThemePreference.system,
  }) : super(ThemeState(preference: initialPreference));

  final UserPreferencesRepository userPreferences;

  Future<void>? _setInFlight;

  Future<void> setThemePreference(AstraThemePreference preference) async {
    if (state.preference == preference) {
      return;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    operation = _persistAndEmit(preference, waitFor);
    _setInFlight = operation;
    try {
      await operation;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<void> _persistAndEmit(
    AstraThemePreference preference,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.preference == preference) {
      return;
    }
    await userPreferences.setThemeMode(preference);
    if (isClosed || state.preference == preference) {
      return;
    }
    emit(ThemeState(preference: preference));
  }
}
