/// Read-only snapshot of SQLite storage footprint for My Data display.
class DatabaseFootprint {
  const DatabaseFootprint({
    required this.sampleCount,
    required this.fileSizeBytes,
  });

  final int sampleCount;
  final int fileSizeBytes;
}
