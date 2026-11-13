import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/import_export/models/import_result.dart';
import 'package:lunora/core/import_export/models/spreadsheet_document.dart';

class DiaryExcelImportService {
  DiaryExcelImportService._();

  static final DiaryExcelImportService instance = DiaryExcelImportService._();
  static const Uuid _uuid = Uuid();

  Future<ImportResult> importWorkbook(SpreadsheetDocument document) async {
    final entriesSheet = _findSheet(document, ['📝 Мои записи', 'Мои записи']);
    final favoritesSheet = _findSheet(document, [
      '💗 Любимые моменты',
      'Любимые моменты',
    ]);
    if (entriesSheet == null) {
      return ImportResult.failure(
        message: 'В книге не найден лист «Мои записи».',
      );
    }

    final rows = _readTable(entriesSheet, headerRow: 7);
    if (rows.isEmpty) {
      return ImportResult.failure(
        message: 'На листе «Мои записи» нет записей для импорта.',
      );
    }

    final favoriteIds = <String>{};
    if (favoritesSheet != null) {
      for (final row in _readTable(favoritesSheet, headerRow: 9)) {
        final id = _value(row, ['ID записи']).toString().trim();
        if (id.isNotEmpty) favoriteIds.add(id);
      }
    }

    final db = await LunoraDatabase.instance.database;
    var imported = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      final existing = await txn.query('diary_entries');
      final existingSourceIds = existing
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.startsWith('excel_diary_'))
          .toSet();
      final existingSignatures = existing
          .map(
            (row) => _signature(
              row['title']?.toString() ?? '',
              row['entry_date']?.toString() ?? '',
              row['content']?.toString() ?? '',
            ),
          )
          .toSet();

      for (final row in rows) {
        final sourceId = _string(row, ['ID записи']);
        final title = _string(row, ['Заголовок']);
        final content = _cleanText(_string(row, ['Текст записи']));
        final date = _date(_value(row, ['Дата записи']));
        if (title.isEmpty || content.isEmpty || date == null) {
          skipped++;
          continue;
        }

        final dateKey = _dateOnly(date);
        final signature = _signature(title, dateKey, content);
        final id = 'excel_diary_${sourceId.isEmpty ? _uuid.v4() : sourceId}';
        if (existingSourceIds.contains(id) ||
            existingSignatures.contains(signature)) {
          skipped++;
          continue;
        }

        final now = DateTime.now().toIso8601String();
        final created = _date(_value(row, ['Дата создания'])) ?? date;
        final mood = _string(row, ['Настроение']);
        final category = _string(row, ['Категория']);
        final type = _string(row, ['Тип записи']).toLowerCase();
        final tags = _string(row, ['Теги'])
            .split(RegExp(r'[,;]'))
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
        final favoriteValue = _string(row, ['Избранное']).toLowerCase();
        final isFavorite =
            favoriteIds.contains(sourceId) ||
            ['да', 'yes', 'true', '1', '✓'].contains(favoriteValue);

        await txn.insert('diary_entries', {
          'id': id,
          'title': title,
          'content': content,
          'entry_date': dateKey,
          'created_at': created.toIso8601String(),
          'updated_at': now,
          'mood': mood.isEmpty ? null : mood,
          'category': category.isEmpty ? 'Без категории' : category,
          'entry_type': type.contains('воспомин') ? 'memory' : 'diary',
          'is_favorite': isFavorite ? 1 : 0,
          'tags': _encodeTags(tags),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        imported++;
        existingSourceIds.add(id);
        existingSignatures.add(signature);
      }
    });

    return ImportResult.success(
      importedCount: imported,
      message: 'Дневник: импортировано $imported записей, пропущено $skipped.',
    );
  }

  SpreadsheetSheetData? _findSheet(
    SpreadsheetDocument doc,
    List<String> names,
  ) {
    for (final sheet in doc.sheets) {
      final normalized = _normalize(sheet.name);
      if (names.any((name) => _normalize(name) == normalized)) return sheet;
    }
    return null;
  }

  List<Map<String, Object?>> _readTable(
    SpreadsheetSheetData sheet, {
    required int headerRow,
  }) {
    if (sheet.rows.length < headerRow) return [];
    final headers = sheet.rows[headerRow - 1]
        .map((e) => _normalize(e?.toString() ?? ''))
        .toList();
    final result = <Map<String, Object?>>[];
    for (final cells in sheet.rows.skip(headerRow)) {
      final row = <String, Object?>{};
      for (var i = 0; i < headers.length && i < cells.length; i++) {
        if (headers[i].isNotEmpty) row[headers[i]] = cells[i];
      }
      if (row.values.any(
        (value) => value != null && value.toString().trim().isNotEmpty,
      )) {
        result.add(row);
      }
    }
    return result;
  }

  Object? _value(Map<String, Object?> row, List<String> names) {
    for (final name in names) {
      final key = _normalize(name);
      if (row.containsKey(key)) return row[key];
    }
    return null;
  }

  String _string(Map<String, Object?> row, List<String> names) =>
      _value(row, names)?.toString().trim() ?? '';
  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s+'), ' ');
  String _signature(String title, String date, String content) =>
      '${_normalize(title)}|$date|${content.trim()}';
  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _encodeTags(List<String> tags) => jsonEncode(tags);

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    }
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _cleanText(String value) => value
      .replaceAll('_x000D_\n', '\n')
      .replaceAll('_x000D_', '\n')
      .replaceAll('\r\n', '\n')
      .trim();
}
