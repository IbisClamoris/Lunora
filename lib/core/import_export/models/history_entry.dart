enum HistoryType { import, export }

class HistoryEntry {
  final String id;
  final String fileName;
  final String? sourceModule;
  final DateTime date;
  final int? recordCount;
  final String status;
  final String? details;
  final HistoryType type;

  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.sourceModule,
    required this.date,
    required this.recordCount,
    required this.status,
    required this.details,
    required this.type,
  });

  bool get isSuccessful {
    final normalized = status.toLowerCase().trim();

    return normalized == 'success' ||
        normalized == 'successful' ||
        normalized == 'completed' ||
        normalized == 'успешно' ||
        normalized == 'завершено';
  }

  factory HistoryEntry.fromImportMap(Map<String, Object?> map) {
    return HistoryEntry(
      id: map['id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'Без названия',
      sourceModule: map['source_module']?.toString(),
      date: _parseDate(map['imported_at']),
      recordCount: _parseCount(map['imported_count']),
      status: map['status']?.toString() ?? 'unknown',
      details: map['details']?.toString(),
      type: HistoryType.import,
    );
  }

  factory HistoryEntry.fromExportMap(Map<String, Object?> map) {
    return HistoryEntry(
      id: map['id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'Без названия',
      sourceModule: map['source_module']?.toString(),
      date: _parseDate(map['exported_at']),
      recordCount: null,
      status: map['status']?.toString() ?? 'unknown',
      details: map['details']?.toString(),
      type: HistoryType.export,
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.tryParse(value.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int? _parseCount(Object? value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }
}
