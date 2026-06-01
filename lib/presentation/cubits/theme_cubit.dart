import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/user_preferences_repository.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({
    required this.userPreferences,
    AstraThemePreference initialPreference = AstraThemePreference.system,
  }) : super(ThemeState(preference: initialPreference));

  final UserPreferencesRepository userPreferences;

  Future<void> setThemePreference(AstraThemePreference preference) async {
    await userPreferences.setThemeMode(preference);
    emit(ThemeState(preference: preference));
  }
}
