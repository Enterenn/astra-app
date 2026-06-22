import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/contracts/user_settings_repository_contract.dart';
import 'locale_state.dart';

class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit({
    required this.userSettings,
    String? initialLanguageCode,
  }) : super(LocaleState(explicitLanguageCode: initialLanguageCode));

  final UserSettingsRepositoryContract userSettings;

  Future<void>? _setInFlight;

  Future<bool> setLanguage(String languageCode) {
    return setLanguagePreference(languageCode);
  }

  Future<bool> setLanguagePreference(String? languageCode) async {
    if (state.explicitLanguageCode == languageCode) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistLanguagePreferenceAndEmit(languageCode, waitFor);
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

  Future<bool> _persistLanguagePreferenceAndEmit(
    String? languageCode,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.explicitLanguageCode == languageCode) {
      return false;
    }
    try {
      if (languageCode == null) {
        await userSettings.clearAppLocale();
      } else {
        await userSettings.setAppLocale(languageCode);
      }
    } catch (_) {
      return false;
    }
    if (isClosed || state.explicitLanguageCode == languageCode) {
      return false;
    }
    emit(LocaleState(explicitLanguageCode: languageCode));
    return true;
  }
}
