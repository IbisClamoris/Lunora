import 'spreadsheet_document.dart';

class ExportDocument {
  final String sourceModule;
  final String fileName;
  final List<ExportSheetOption> sheets;

  const ExportDocument({
    required this.sourceModule,
    required this.fileName,
    required this.sheets,
  });

  List<SpreadsheetSheetData> get selectedSheets {
    return sheets
        .where((sheet) => sheet.isSelected)
        .map((sheet) => sheet.data)
        .toList();
  }

  int get sheetCount => sheets.length;

  int get selectedSheetCount {
    return sheets.where((sheet) => sheet.isSelected).length;
  }

  int get totalRowCount {
    return sheets.fold(0, (total, sheet) => total + sheet.data.rowCount);
  }

  int get selectedRowCount {
    return sheets
        .where((sheet) => sheet.isSelected)
        .fold(0, (total, sheet) => total + sheet.data.rowCount);
  }

  bool get hasSelectedSheets => selectedSheets.isNotEmpty;

  ExportDocument copyWith({
    String? sourceModule,
    String? fileName,
    List<ExportSheetOption>? sheets,
  }) {
    return ExportDocument(
      sourceModule: sourceModule ?? this.sourceModule,
      fileName: fileName ?? this.fileName,
      sheets: sheets ?? this.sheets,
    );
  }
}

class ExportSheetOption {
  final SpreadsheetSheetData data;
  final bool isSelected;

  const ExportSheetOption({required this.data, this.isSelected = true});

  ExportSheetOption copyWith({SpreadsheetSheetData? data, bool? isSelected}) {
    return ExportSheetOption(
      data: data ?? this.data,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
