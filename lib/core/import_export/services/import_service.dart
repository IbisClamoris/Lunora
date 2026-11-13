import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';

import '../models/import_result.dart';
import '../models/spreadsheet_document.dart';

typedef ImportTransactionHandler = Future<int> Function(
  Transaction transaction,
  List<Map<String, Object?>> records,
);

class ImportService {
  ImportService._();

  static final ImportService instance = ImportService._();

  static const Uuid _uuid = Uuid();

  Future<ImportResult> importSheet({
    required String fileName,
    required String sourceModule,
    required SpreadsheetSheetData sheet,
    required Map<int, String> columnMapping,
    required ImportTransactionHandler importer,
    List<String> requiredFields = const [],
  }) async {
    final database = await LunoraDatabase.instance.database;

    final validationErrors = _validateConfiguration(
      sheet: sheet,
      columnMapping: columnMapping,
      requiredFields: requiredFields,
    );

    if (validationErrors.isNotEmpty) {
      await _saveFailedHistory(
        database: database,
        fileName: fileName,
        sourceModule: sourceModule,
        errors: validationErrors,
      );

      return ImportResult.failure(
        message: 'Не удалось проверить данные для импорта.',
        errors: validationErrors,
      );
    }

    final recordsResult = _prepareRecords(
      sheet: sheet,
      columnMapping: columnMapping,
      requiredFields: requiredFields,
    );

    if (recordsResult.errors.isNotEmpty) {
      await _saveFailedHistory(
        database: database,
        fileName: fileName,
        sourceModule: sourceModule,
        errors: recordsResult.errors,
      );

      return ImportResult.failure(
        message: 'В файле обнаружены ошибки в данных.',
        errors: recordsResult.errors,
      );
    }

    if (recordsResult.records.isEmpty) {
      const errors = ['В файле нет строк для импорта.'];

      await _saveFailedHistory(
        database: database,
        fileName: fileName,
        sourceModule: sourceModule,
        errors: errors,
      );

      return ImportResult.failure(
        message: 'Нет данных для импорта.',
        errors: errors,
      );
    }

    try {
      final importedCount = await database.transaction<int>((
        transaction,
      ) async {
        final count = await importer(transaction, recordsResult.records);

        await transaction.insert('import_history', {
          'id': _uuid.v4(),
          'file_name': fileName,
          'source_module': sourceModule,
          'imported_at': DateTime.now().toIso8601String(),
          'imported_count': count,
          'status': 'success',
          'details': 'Импортировано записей: $count',
        });

        return count;
      });

      return ImportResult.success(importedCount: importedCount);
    } catch (error) {
      final errors = [
        'Ошибка записи данных: $error',
        'Все изменения транзакции отменены.',
      ];

      await _saveFailedHistory(
        database: database,
        fileName: fileName,
        sourceModule: sourceModule,
        errors: errors,
      );

      return ImportResult.failure(
        message: 'Импорт отменён. Данные не были сохранены.',
        errors: errors,
      );
    }
  }

  List<String> _validateConfiguration({
    required SpreadsheetSheetData sheet,
    required Map<int, String> columnMapping,
    required List<String> requiredFields,
  }) {
    final errors = <String>[];

    if (sheet.rows.isEmpty) {
      errors.add('Лист Excel пуст.');
      return errors;
    }

    if (sheet.rows.length < 2) {
      errors.add('В листе отсутствуют строки с данными.');
    }

    if (columnMapping.isEmpty) {
      errors.add('Не настроено сопоставление колонок.');
    }

    final usedFields = <String>{};

    for (final entry in columnMapping.entries) {
      final columnIndex = entry.key;
      final field = entry.value.trim();

      if (columnIndex < 0 || columnIndex >= sheet.columnCount) {
        errors.add('Некорректный индекс колонки: $columnIndex.');
      }

      if (field.isEmpty) {
        errors.add('Обнаружено сопоставление с пустым полем.');
      } else if (!usedFields.add(field)) {
        errors.add('Поле "$field" сопоставлено несколько раз.');
      }
    }

    for (final requiredField in requiredFields) {
      if (!usedFields.contains(requiredField)) {
        errors.add('Не сопоставлено обязательное поле "$requiredField".');
      }
    }

    return errors;
  }

  _PreparedRecords _prepareRecords({
    required SpreadsheetSheetData sheet,
    required Map<int, String> columnMapping,
    required List<String> requiredFields,
  }) {
    final records = <Map<String, Object?>>[];
    final errors = <String>[];

    final dataRows = sheet.rows.skip(1);

    var rowNumber = 1;

    for (final row in dataRows) {
      rowNumber++;

      final isEmpty = row.every(
        (value) => value == null || value.toString().trim().isEmpty,
      );

      if (isEmpty) continue;

      final record = <String, Object?>{};

      for (final entry in columnMapping.entries) {
        final columnIndex = entry.key;
        final field = entry.value.trim();

        record[field] = columnIndex >= row.length
            ? null
            : _normalizeValue(row[columnIndex]);
      }

      for (final requiredField in requiredFields) {
        final value = record[requiredField];

        if (value == null || value.toString().trim().isEmpty) {
          errors.add(
            'Строка $rowNumber: не заполнено обязательное поле '
            '"$requiredField".',
          );
        }
      }

      records.add(record);
    }

    return _PreparedRecords(records: records, errors: errors);
  }

  Object? _normalizeValue(Object? value) {
    if (value == null) return null;

    if (value is bool) return value ? 1 : 0;

    if (value is DateTime) return value.toIso8601String();

    if (value is Duration) return value.toString();

    if (value is String || value is int || value is double) {
      return value;
    }

    if (value is num) return value;

    return value.toString();
  }

  Future<void> _saveFailedHistory({
    required Database database,
    required String fileName,
    required String sourceModule,
    required List<String> errors,
  }) async {
    try {
      await database.insert('import_history', {
        'id': _uuid.v4(),
        'file_name': fileName,
        'source_module': sourceModule,
        'imported_at': DateTime.now().toIso8601String(),
        'imported_count': 0,
        'status': 'failed',
        'details': errors.join('\n'),
      });
    } catch (_) {
      // Не скрываем первоначальную ошибку импорта.
    }
  }
}

class _PreparedRecords {
  final List<Map<String, Object?>> records;
  final List<String> errors;

  const _PreparedRecords({required this.records, required this.errors});
}
