class ImportResult {
  const ImportResult({
    required this.totalRowsInFile,
    required this.insertedCount,
    required this.skippedCount,
  });

  final int totalRowsInFile;
  final int insertedCount;
  final int skippedCount;
}
