/// Thrown when CSV import validation fails before any database write (FR-30).
class ImportValidationException implements Exception {
  ImportValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
