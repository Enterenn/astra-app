/// Persisted accent preset IDs (English names, SQLite `accent_preset` values).
enum AstraAccentPreset {
  orange,
  red,
  green,
  blue,
  magenta,
  pink,
}

/// Default accent when preference is missing or invalid.
const kDefaultAccentPreset = AstraAccentPreset.orange;

/// Parses stored `accent_preset` values with legacy aliases.
AstraAccentPreset parseAccentPreset(String? raw) {
  return switch (raw) {
    'orange' => AstraAccentPreset.orange,
    'red' => AstraAccentPreset.red,
    'green' => AstraAccentPreset.green,
    'blue' => AstraAccentPreset.blue,
    'magenta' => AstraAccentPreset.magenta,
    'pink' => AstraAccentPreset.pink,
    'cyan' => AstraAccentPreset.blue,
    'purple' => AstraAccentPreset.magenta,
    _ => kDefaultAccentPreset,
  };
}

String accentPresetToStorage(AstraAccentPreset preset) => switch (preset) {
  AstraAccentPreset.orange => 'orange',
  AstraAccentPreset.red => 'red',
  AstraAccentPreset.green => 'green',
  AstraAccentPreset.blue => 'blue',
  AstraAccentPreset.magenta => 'magenta',
  AstraAccentPreset.pink => 'pink',
};
