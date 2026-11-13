class SpreadsheetDocument {
  final String sourceFileName;
  final List<SpreadsheetSheetData> sheets;

  const SpreadsheetDocument({
    required this.sourceFileName,
    required this.sheets,
  });

  int get sheetCount => sheets.length;

  int get totalRowCount {
    return sheets.fold(0, (total, sheet) => total + sheet.rows.length);
  }
}

class SpreadsheetSheetData {
  final String name;
  final List<List<Object?>> rows;

  const SpreadsheetSheetData({required this.name, required this.rows});

  int get rowCount => rows.length;

  int get columnCount {
    if (rows.isEmpty) return 0;

    return rows.fold<int>(
      0,
      (maximum, row) => row.length > maximum ? row.length : maximum,
    );
  }

  List<String> get headers {
    if (rows.isEmpty) return [];

    return rows.first.map((value) => value?.toString() ?? '').toList();
  }
}
