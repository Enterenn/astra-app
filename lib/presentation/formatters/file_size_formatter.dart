/// Human-readable file size formatting without the `intl` package.
String formatFileSize(int bytes) {
  if (bytes < 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }

  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes < mb) {
    final kbValue = bytes / kb;
    return '${kbValue.round()} KB';
  }
  if (bytes < gb) {
    final mbValue = bytes / mb;
    return '${mbValue.toStringAsFixed(1)} MB';
  }

  final gbValue = bytes / gb;
  return '${gbValue.toStringAsFixed(1)} GB';
}
