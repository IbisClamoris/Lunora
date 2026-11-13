import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/import_export/models/spreadsheet_document.dart';
import 'package:lunora/core/import_export/models/import_result.dart';

class BookExcelImportService {
  BookExcelImportService._();

  static final BookExcelImportService instance = BookExcelImportService._();

  Future<ImportResult> importWorkbook(SpreadsheetDocument document) async {
    try {
      final sheet = _findSheet(document, 'Библиотека');

      if (sheet == null) {
        return ImportResult.failure(
          message: 'В книге не найден лист «Библиотека».',
        );
      }

      final rows = _readRows(sheet);

      if (rows.isEmpty) {
        return ImportResult.failure(
          message: 'Лист «Библиотека» не содержит книг.',
        );
      }

      final db = await LunoraDatabase.instance.database;

      var importedCount = 0;
      var skippedCount = 0;

      await db.transaction((txn) async {
        final existingRows = await txn.query('book_entries');

        final existingIds = existingRows
            .map((row) => row['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();

        final existingSignatures = existingRows.map((row) {
          return _signature(
            row['title']?.toString() ?? '',
            row['authors']?.toString() ?? '',
          );
        }).toSet();

        for (final row in rows) {
          final title = _string(row, ['Название']);

          if (title.isEmpty) {
            skippedCount++;
            continue;
          }

          final authors = _string(row, ['Автор']);
          final sourceId = _string(row, ['ID']);

          final signature = _signature(title, authors);

          if ((sourceId.isNotEmpty && existingIds.contains(sourceId)) ||
              existingSignatures.contains(signature)) {
            skippedCount++;
            continue;
          }

          final now = DateTime.now().toIso8601String();

          final createdAt =
              _date(_value(row, ['Дата создания', 'Создано']))
                  ?.toIso8601String() ??
              now;

          final updatedAt =
              _date(_value(row, ['Дата обновления', 'Обновлено']))
                  ?.toIso8601String() ??
              createdAt;

          final genre = _string(row, ['Жанры']);

          final entry = <String, Object?>{
            'id': sourceId.isNotEmpty ? sourceId : _newId(),
            'title': title,
            'authors': authors,
            'description': '',
            'cover_path': null,
            'genre': genre,
            'tags': '',
            'status': _status(_string(row, ['Статус'])),
            'rating': _rating(_value(row, ['Оценка'])),
            'review': _string(row, ['Впечатления']),
            'started_at': _date(_value(row, ['Начало чтения']))
                ?.toIso8601String(),
            'finished_at': _date(_value(row, ['Завершение']))
                ?.toIso8601String(),
            'page_count': null,
            'current_page': 0,
            'is_favorite': _boolean(_value(row, ['Избранное'])) ? 1 : 0,
            'created_at': createdAt,
            'updated_at': updatedAt,
            'series_name': _string(row, ['Серия / цикл']),
            'series_number': _number(_value(row, ['№ в серии'])),
            'book_format': _string(row, ['Формат']),
            'source_name': _string(row, ['Источник']),
          };

          await txn.insert(
            'book_entries',
            entry,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          existingIds.add(entry['id'].toString());
          existingSignatures.add(signature);

          importedCount++;
        }
      });

      return ImportResult.success(
        importedCount: importedCount,
        message: skippedCount > 0
            ? 'Импортировано книг: $importedCount. '
                  'Пропущено: $skippedCount.'
            : 'Импортировано книг: $importedCount.',
      );
    } catch (error) {
      return ImportResult.failure(
        message: 'Не удалось импортировать книги.',
        errors: [error.toString()],
      );
    }
  }

  SpreadsheetSheetData? _findSheet(SpreadsheetDocument document, String name) {
    final normalizedName = _normalize(name);

    for (final sheet in document.sheets) {
      if (_normalize(sheet.name) == normalizedName) {
        return sheet;
      }
    }

    return null;
  }

  List<Map<String, Object?>> _readRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((value) => _normalize(value?.toString() ?? ''))
        .toList();

    final result = <Map<String, Object?>>[];

    for (final row in sheet.rows.skip(1)) {
      final values = <String, Object?>{};

      for (var i = 0; i < headers.length; i++) {
        if (headers[i].isEmpty) continue;

        values[headers[i]] = i < row.length ? row[i] : null;
      }

      if (values.values.every(
        (value) => value == null || value.toString().trim().isEmpty,
      )) {
        continue;
      }

      result.add(values);
    }

    return result;
  }

  Object? _value(Map<String, Object?> row, List<String> names) {
    for (final name in names) {
      final key = _normalize(name);

      if (row.containsKey(key)) {
        return row[key];
      }
    }

    return null;
  }

  String _string(Map<String, Object?> row, List<String> names) {
    return _value(row, names)?.toString().trim() ?? '';
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _signature(String title, String authors) {
    return '${_normalize(title)}|${_normalize(authors)}';
  }

  String _status(String value) {
    final normalized = _normalize(value);

    if (normalized.contains('читаю')) return 'reading';
    if (normalized.contains('прочитан')) return 'completed';
    if (normalized.contains('план')) return 'planned';

    switch (normalized) {
      case 'reading':
        return 'reading';
      case 'completed':
        return 'completed';
      case 'planned':
        return 'planned';
      default:
        return 'planned';
    }
  }

  double? _rating(Object? value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    final text = value.toString().trim().replaceAll(',', '.');
    return double.tryParse(text);
  }

  double? _number(Object? value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  bool _boolean(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = _normalize(value.toString());

    return text == 'да' ||
        text == 'true' ||
        text == '1' ||
        text == 'избранное' ||
        text == '❤️';
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
    }

    if (value is double) {
      final milliseconds = ((value - 25569) * 86400000).round();

      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) return isoDate;

    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(text);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      return DateTime(year, month, day);
    }

    return null;
  }

  String _newId() {
    return 'BOOK-${DateTime.now().microsecondsSinceEpoch}';
  }
}
