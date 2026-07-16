import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../data/contracts/user_settings_repository_contract.dart';
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

  final UserSettingsRepositoryContract userSettings;

  Future<void>? _setInFlight;

  Future<bool> setThemePreference(AstraThemePreference preference) async {
    if (state.preference == preference) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistThemeAndEmit(preference, waitFor);
    }();
    _setInFlight = operation;
    try {
      await operation;
      return success;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<bool> setAccentPreset(AstraAccentPreset preset) async {
    if (state.accentPreset == preset) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistAccentAndEmit(preset, waitFor);
    }();
    _setInFlight = operation;
    try {
      await operation;
      return success;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<bool> _persistThemeAndEmit(
    AstraThemePreference preference,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.preference == preference) {
      return false;
    }
    try {
      await userSettings.setThemeMode(preference);
    } catch (_) {
      return false;
    }
    if (isClosed || state.preference == preference) {
      return false;
    }
    emit(ThemeState(preference: preference, accentPreset: state.accentPreset));
    return true;
  }

  Future<bool> _persistAccentAndEmit(
    AstraAccentPreset preset,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.accentPreset == preset) {
      return false;
    }
    try {
      await userSettings.setAccentPreset(preset);
    } catch (_) {
      return false;
    }
    if (isClosed || state.accentPreset == preset) {
      return false;
    }
    emit(ThemeState(preference: state.preference, accentPreset: preset));
    return true;
  }
}
