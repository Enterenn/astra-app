/// Derives one or two uppercase initials from a local display name.
String? initialsFromDisplayName(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return null;
  }

  String firstGrapheme(String value) {
    final runes = value.runes;
    if (runes.isEmpty) {
      return '';
    }
    return String.fromCharCodes([runes.first]).toUpperCase();
  }

  if (parts.length == 1) {
    final initial = firstGrapheme(parts.first);
    return initial.isEmpty ? null : initial;
  }

  final first = firstGrapheme(parts.first);
  final last = firstGrapheme(parts.last);
  final combined = first + last;
  return combined.isEmpty ? null : combined;
}

/// Whether [name] has non-whitespace content after trim.
bool hasTrimmedDisplayName(String? name) {
  final trimmed = name?.trim();
  return trimmed != null && trimmed.isNotEmpty;
}
