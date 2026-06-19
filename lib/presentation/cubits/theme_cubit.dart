import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../data/repositories/user_settings_repository.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({
    required this.userSettings,
    AstraThemePreference initialPreference = AstraThemePreference.system,
    AstraAccentPreset initialAccentPreset = kDefaultAccentPreset,
  }) : super(
         ThemeState(
           preference: initialPreference,
           accentPreset: initialAccentPreset,
         ),
       );

  final UserSettingsRepository userSettings;

  Future<void>? _setInFlight;

  Future<void> setThemePreference(AstraThemePreference preference) async {
    if (state.preference == preference) {
      return;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    operation = _persistThemeAndEmit(preference, waitFor);
    _setInFlight = operation;
    try {
      await operation;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<void> setAccentPreset(AstraAccentPreset preset) async {
    if (state.accentPreset == preset) {
      return;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    operation = _persistAccentAndEmit(preset, waitFor);
    _setInFlight = operation;
    try {
      await operation;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<void> _persistThemeAndEmit(
    AstraThemePreference preference,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.preference == preference) {
      return;
    }
    await userSettings.setThemeMode(preference);
    if (isClosed || state.preference == preference) {
      return;
    }
    emit(ThemeState(preference: preference, accentPreset: state.accentPreset));
  }

  Future<void> _persistAccentAndEmit(
    AstraAccentPreset preset,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.accentPreset == preset) {
      return;
    }
    await userSettings.setAccentPreset(preset);
    if (isClosed || state.accentPreset == preset) {
      return;
    }
    emit(ThemeState(preference: state.preference, accentPreset: preset));
  }
}
