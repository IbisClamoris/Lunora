class ImportResult {
  final bool success;
  final int importedCount;
  final String message;
  final List<String> errors;
  final DateTime completedAt;

  const ImportResult({
    required this.success,
    required this.importedCount,
    required this.message,
    this.errors = const [],
    required this.completedAt,
  });

  factory ImportResult.success({
    required int importedCount,
    String message = 'Импорт успешно завершён.',
  }) {
    return ImportResult(
      success: true,
      importedCount: importedCount,
      message: message,
      completedAt: DateTime.now(),
    );
  }

  factory ImportResult.failure({
    required String message,
    List<String> errors = const [],
  }) {
    return ImportResult(
      success: false,
      importedCount: 0,
      message: message,
      errors: errors,
      completedAt: DateTime.now(),
    );
  }
}
