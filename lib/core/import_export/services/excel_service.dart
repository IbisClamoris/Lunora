import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/storage/storage_service.dart';

import '../models/spreadsheet_document.dart';

class ExcelService {
  ExcelService._();

  static final ExcelService instance = ExcelService._();

  static const Uuid _uuid = Uuid();

  Future<SpreadsheetDocument> readWorkbook(File file) async {
    if (!await file.exists()) {
      throw const FormatException('Выбранный Excel-файл не найден.');
    }

    final extension = p.extension(file.path).toLowerCase();

    if (extension != '.xlsx' && extension != '.xlsm') {
      throw const FormatException(
        'Поддерживаются файлы форматов .xlsx и .xlsm.',
      );
    }

    try {
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw const FormatException('Выбранный Excel-файл пуст.');
      }

      final workbook = Excel.decodeBytes(bytes);
      final sheets = <SpreadsheetSheetData>[];

      for (final entry in workbook.tables.entries) {
        final sheetName = entry.key;
        final sheet = entry.value;

        final rows = sheet.rows.map((row) {
          return row.map(_readCellValue).toList();
        }).toList();

        sheets.add(SpreadsheetSheetData(name: sheetName, rows: rows));
      }

      if (sheets.isEmpty) {
        throw const FormatException(
          'В Excel-файле не найдено ни одного листа.',
        );
      }

      return SpreadsheetDocument(
        sourceFileName: p.basename(file.path),
        sheets: sheets,
      );
    } on FormatException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Ошибка чтения Excel: $error');
      debugPrintStack(stackTrace: stackTrace);

      throw FormatException('Не удалось прочитать Excel-файл: $error');
    }
  }

  Future<File> exportWorkbook({
    required String fileName,
    required List<SpreadsheetSheetData> sheets,
    String? sourceModule,
  }) async {
    try {
      if (sheets.isEmpty) {
        throw const FormatException('Нет листов для экспорта.');
      }

      final workbook = Excel.createExcel();
      final usedSheetNames = <String>{};
      var isFirstSheet = true;

      for (final sheetData in sheets) {
        final sheetName = _createUniqueSheetName(
          sheetData.name,
          usedSheetNames,
        );

        usedSheetNames.add(sheetName);

        if (isFirstSheet) {
          workbook.rename('Sheet1', sheetName);
          isFirstSheet = false;
        }

        final sheet = workbook[sheetName];

        for (final row in sheetData.rows) {
          sheet.appendRow(row.map(_createCellValue).toList());
        }
      }

      final bytes = workbook.encode();

      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Не удалось сформировать Excel-файл.');
      }

      final exportDirectory = await StorageService.instance.exportsDirectory;

      final safeFileName = _sanitizeFileName(fileName);
      final finalFileName = _createUniqueFileName(
        exportDirectory.path,
        safeFileName,
      );

      final outputFile = File(p.join(exportDirectory.path, finalFileName));

      await outputFile.writeAsBytes(bytes, flush: true);

      final rowCount = sheets.fold<int>(
        0,
        (sum, sheet) => sum + sheet.rowCount,
      );

      await _saveExportHistory(
        fileName: p.basename(outputFile.path),
        sourceModule: sourceModule,
        status: 'success',
        details:
            'Экспорт завершён. Листов: ${sheets.length}. Строк: $rowCount.',
      );

      return outputFile;
    } on FormatException catch (error) {
      await _saveExportHistory(
        fileName: fileName,
        sourceModule: sourceModule,
        status: 'failed',
        details: error.message,
      );

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Ошибка экспорта Excel: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _saveExportHistory(
        fileName: fileName,
        sourceModule: sourceModule,
        status: 'failed',
        details: error.toString(),
      );

      throw FormatException('Не удалось экспортировать Excel-файл: $error');
    }
  }

  Future<void> _saveExportHistory({
    required String fileName,
    required String? sourceModule,
    required String status,
    required String details,
  }) async {
    try {
      final Database db = await LunoraDatabase.instance.database;

      await db.insert('export_history', {
        'id': _uuid.v4(),
        'file_name': fileName,
        'source_module': sourceModule,
        'exported_at': DateTime.now().toIso8601String(),
        'status': status,
        'details': details,
      });
    } catch (_) {
      // Ошибка истории не должна отменять сам экспорт.
    }
  }

  Object? _readCellValue(dynamic cell) {
    final value = cell?.value;

    if (value == null) {
      return null;
    }

    switch (value) {
      case TextCellValue():
        return value.value.toString();
      case IntCellValue():
        return value.value;
      case DoubleCellValue():
        return value.value;
      case BoolCellValue():
        return value.value;
      case DateCellValue():
        return value.asDateTimeLocal().toIso8601String();
      case DateTimeCellValue():
        return value.asDateTimeLocal().toIso8601String();
      case TimeCellValue():
        return value.asDuration().toString();
      case FormulaCellValue():
        return value.formula;
      default:
        return value.toString();
    }
  }

  CellValue? _createCellValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return TextCellValue(value);
    }

    if (value is int) {
      return IntCellValue(value);
    }

    if (value is double) {
      return DoubleCellValue(value);
    }

    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }

    if (value is bool) {
      return BoolCellValue(value);
    }

    if (value is DateTime) {
      return TextCellValue(value.toIso8601String());
    }

    if (value is Duration) {
      return TextCellValue(value.toString());
    }

    return TextCellValue(value.toString());
  }

  String _sanitizeSheetName(String name) {
    var result = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), '_').trim();

    if (result.isEmpty) {
      result = 'Лист';
    }

    if (result.length > 31) {
      result = result.substring(0, 31);
    }

    return result;
  }

  String _createUniqueSheetName(String originalName, Set<String> usedNames) {
    final baseName = _sanitizeSheetName(originalName);
    var candidate = baseName;
    var counter = 2;

    while (usedNames.contains(candidate)) {
      final suffix = '_$counter';
      final availableLength = 31 - suffix.length;

      final prefix = baseName.length > availableLength
          ? baseName.substring(0, availableLength)
          : baseName;

      candidate = '$prefix$suffix';
      counter++;
    }

    return candidate;
  }

  String _sanitizeFileName(String fileName) {
    var result = p
        .basenameWithoutExtension(fileName)
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    if (result.isEmpty) {
      result = 'Lunora_Export';
    }

    return '$result.xlsx';
  }

  String _createUniqueFileName(String directoryPath, String fileName) {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);

    var candidate = fileName;
    var counter = 2;

    while (File(p.join(directoryPath, candidate)).existsSync()) {
      candidate = '${baseName}_$counter$extension';
      counter++;
    }

    return candidate;
  }
}
