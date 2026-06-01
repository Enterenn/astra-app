import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({AstraThemePreference initialPreference = AstraThemePreference.system})
      : super(ThemeState(preference: initialPreference));
}
