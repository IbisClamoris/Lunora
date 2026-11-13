import '../models/export_document.dart';
import '../models/spreadsheet_document.dart';

class ExportPreparationService {
  ExportPreparationService._();

  static final ExportPreparationService instance = ExportPreparationService._();

  /// Подготавливает данные для последующего экспорта.
  ExportDocument prepare({
    required String sourceModule,
    required String fileName,
    required List<SpreadsheetSheetData> sheets,
    Set<int>? selectedSheetIndexes,
  }) {
    final normalizedModule = sourceModule.trim();
    final normalizedFileName = fileName.trim();

    if (normalizedModule.isEmpty) {
      throw const FormatException('Не указан раздел для экспорта.');
    }

    if (normalizedFileName.isEmpty) {
      throw const FormatException('Не указано имя экспортируемого файла.');
    }

    if (sheets.isEmpty) {
      throw const FormatException('Нет листов для экспорта.');
    }

    if (selectedSheetIndexes != null) {
      for (final index in selectedSheetIndexes) {
        if (index < 0 || index >= sheets.length) {
          throw FormatException('Выбран несуществующий лист. Индекс: $index.');
        }
      }
    }

    final exportSheets = <ExportSheetOption>[];

    for (var index = 0; index < sheets.length; index++) {
      final isSelected =
          selectedSheetIndexes == null || selectedSheetIndexes.contains(index);

      exportSheets.add(
        ExportSheetOption(data: sheets[index], isSelected: isSelected),
      );
    }

    final document = ExportDocument(
      sourceModule: normalizedModule,
      fileName: normalizedFileName,
      sheets: exportSheets,
    );

    validate(document);

    return document;
  }

  /// Проверяет уже подготовленный документ перед экспортом.
  void validate(ExportDocument document) {
    if (document.sourceModule.trim().isEmpty) {
      throw const FormatException('Не указан раздел для экспорта.');
    }

    if (document.fileName.trim().isEmpty) {
      throw const FormatException('Не указано имя экспортируемого файла.');
    }

    if (document.sheets.isEmpty) {
      throw const FormatException('Нет листов для экспорта.');
    }

    if (!document.hasSelectedSheets) {
      throw const FormatException('Выбери хотя бы один лист для экспорта.');
    }

    for (final sheet in document.selectedSheets) {
      if (sheet.name.trim().isEmpty) {
        throw const FormatException(
          'У одного из выбранных листов отсутствует название.',
        );
      }
    }
  }
}
