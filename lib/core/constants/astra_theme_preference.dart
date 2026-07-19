/// Persisted theme mode IDs (SQLite `theme_mode` values).
enum AstraThemePreference { system, light, dark }

/// Default theme when preference is missing or invalid.
const kDefaultThemePreference = AstraThemePreference.system;

AstraThemePreference parseThemePreference(String? raw) => switch (raw) {
  'light' => AstraThemePreference.light,
  'dark' => AstraThemePreference.dark,
  _ => kDefaultThemePreference,
};

String themePreferenceToStorage(AstraThemePreference preference) =>
    switch (preference) {
      AstraThemePreference.light => 'light',
      AstraThemePreference.dark => 'dark',
      AstraThemePreference.system => 'system',
    };
