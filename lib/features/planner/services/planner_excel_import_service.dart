import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/import_export/models/import_result.dart';
import 'package:lunora/core/import_export/models/spreadsheet_document.dart';

class PlannerExcelImportService {
  PlannerExcelImportService._();
  static final PlannerExcelImportService instance =
      PlannerExcelImportService._();
  static const Uuid _uuid = Uuid();

  Future<ImportResult> importWorkbook(SpreadsheetDocument document) async {
    final monthSheet = _findSheet(document, ['📅 Месяц', 'Месяц']);
    if (monthSheet == null) {
      return ImportResult.failure(message: 'В книге не найден лист «Месяц».');
    }
    final weekSheet = _findSheet(document, ['Неделя']);
    final notesSheet = _findSheet(document, ['📝 Мои заметки', 'Мои заметки']);
    final db = await LunoraDatabase.instance.database;

    var importedGoals = 0;
    var importedTasks = 0;
    var importedNotes = 0;
    var skipped = 0;
    final now = DateTime.now().toIso8601String();

    final year = _int(_cell(monthSheet, 3, 2)) ?? DateTime.now().year;
    final month = _monthNumber(_cell(monthSheet, 2, 2)) ?? DateTime.now().month;

    await db.transaction((txn) async {
      // Цели на месяц: I = название, K = отметка выполнения.
      final existingGoals = await txn.query(
        'planner_goals',
        where: 'month = ? AND year = ?',
        whereArgs: [month, year],
      );
      final goalTitles = existingGoals
          .map((r) => _normalize(r['title']?.toString() ?? ''))
          .toSet();
      var goalOrder = existingGoals.length;
      for (var r = 7; r <= 15 && r <= monthSheet.rows.length; r++) {
        final title = _text(_cell(monthSheet, r, 9));
        if (title.isEmpty) continue;
        if (goalTitles.contains(_normalize(title))) {
          skipped++;
          continue;
        }
        final completed = _bool(_cell(monthSheet, r, 11));
        await txn.insert('planner_goals', {
          'id': 'excel_goal_${_uuid.v4()}',
          'title': title,
          'month': month,
          'year': year,
          'is_completed': completed ? 1 : 0,
          'sort_order': goalOrder++,
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        importedGoals++;
        goalTitles.add(_normalize(title));
      }

      final existingTasks = await txn.query('tasks');
      final taskBySignature = <String, Map<String, Object?>>{};
      for (final task in existingTasks) {
        taskBySignature[_taskSignature(
              task['title']?.toString() ?? '',
              _date(task['due_date']),
            )] =
            task;
      }

      Future<void> addTask({
        required String title,
        DateTime? date,
        int? timeMinutes,
        String priority = '',
        String status = '',
        String description = '',
      }) async {
        if (title.trim().isEmpty) return;
        final signature = _taskSignature(title, date);
        final existing = taskBySignature[signature];
        if (existing != null) {
          // Недельное расписание уточняет время задачи из месячного списка.
          if (timeMinutes != null && existing['due_time_minutes'] == null) {
            await txn.update(
              'tasks',
              {'due_time_minutes': timeMinutes, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [existing['id']],
            );
            existing['due_time_minutes'] = timeMinutes;
          }
          skipped++;
          return;
        }
        final normalizedStatus = _status(status);
        final completedAt = normalizedStatus == 'completed' ? now : null;
        final id = 'excel_task_${_uuid.v4()}';
        final row = <String, Object?>{
          'id': id,
          'title': title.trim(),
          'description': description,
          'status': normalizedStatus,
          'priority': _priority(priority),
          'due_date': date?.toIso8601String(),
          'due_time_minutes': timeMinutes,
          'created_at': now,
          'updated_at': now,
          'completed_at': completedAt,
        };
        await txn.insert(
          'tasks',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        taskBySignature[signature] = row;
        importedTasks++;
      }

      // Задачи на месяц: A-D, заголовки в строке 17.
      for (var r = 18; r <= monthSheet.rows.length; r++) {
        final date = _date(_cell(monthSheet, r, 1));
        final title = _text(_cell(monthSheet, r, 2));
        if (title.isEmpty) continue;
        await addTask(
          title: title,
          date: date,
          priority: _text(_cell(monthSheet, r, 3)),
          status: _text(_cell(monthSheet, r, 4)),
          description: 'Импортировано из месячного планера.',
        );
      }

      // Важные даты: O-P, строки после заголовка в 6-й строке.
      for (var r = 7; r <= monthSheet.rows.length; r++) {
        final date = _date(_cell(monthSheet, r, 15));
        final title = _text(_cell(monthSheet, r, 16));
        if (date == null || title.isEmpty) continue;
        await addTask(
          title: title,
          date: date,
          description: 'Важная дата из планера.',
        );
      }

      // Недельная сетка: даты B-H в строке 6, время A в строках 7-23.
      if (weekSheet != null && weekSheet.rows.length >= 6) {
        final dates = <int, DateTime>{};
        for (var col = 2; col <= 8; col++) {
          final date = _date(_cell(weekSheet, 6, col));
          if (date != null) dates[col] = date;
        }
        for (var r = 7; r <= 23 && r <= weekSheet.rows.length; r++) {
          final time = _minutes(_cell(weekSheet, r, 1));
          for (final entry in dates.entries) {
            final title = _text(_cell(weekSheet, r, entry.key));
            if (title.isEmpty) continue;
            await addTask(
              title: title,
              date: entry.value,
              timeMinutes: time,
              description: 'Импортировано из недельного расписания.',
            );
          }
        }
        // Список задач на неделю, столбец J, без назначенной даты.
        for (var r = 7; r <= weekSheet.rows.length; r++) {
          final title = _text(_cell(weekSheet, r, 10));
          if (title.isEmpty) continue;
          await addTask(
            title: title,
            priority: _text(_cell(weekSheet, r, 11)),
            status: _bool(_cell(weekSheet, r, 13)) ? 'Выполнено' : '',
            description: 'Задача из списка недели.',
          );
        }
      }

      // Заметки планера: A-C, заголовок в строке 5.
      if (notesSheet != null) {
        final existingNotes = await txn.query(
          'notes',
          where: 'source_module = ?',
          whereArgs: ['planner'],
        );
        final noteSignatures = existingNotes
            .map((r) => _normalize('${r['title']}|${r['content']}'))
            .toSet();
        for (var r = 6; r <= notesSheet.rows.length; r++) {
          final date = _date(_cell(notesSheet, r, 1));
          final content = _text(_cell(notesSheet, r, 2));
          final category = _text(_cell(notesSheet, r, 3));
          if (content.isEmpty) continue;
          final title = category.isEmpty
              ? 'Заметка${date == null ? '' : ' от ${_dateLabel(date)}'}'
              : category;
          final signature = _normalize('$title|$content');
          if (noteSignatures.contains(signature)) {
            skipped++;
            continue;
          }
          await txn.insert('notes', {
            'id': 'excel_planner_note_${_uuid.v4()}',
            'title': title,
            'content': content,
            'source_module': 'planner',
            'created_at': now,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          noteSignatures.add(signature);
          importedNotes++;
        }
      }
    });

    final total = importedGoals + importedTasks + importedNotes;
    return ImportResult.success(
      importedCount: total,
      message:
          'Планер: цели — $importedGoals, задачи и события — $importedTasks, заметки — $importedNotes. Пропущено: $skipped.',
    );
  }

  SpreadsheetSheetData? _findSheet(
    SpreadsheetDocument doc,
    List<String> names,
  ) {
    for (final sheet in doc.sheets) {
      if (names.any((name) => _normalize(name) == _normalize(sheet.name))) {
        return sheet;
      }
    }
    return null;
  }

  Object? _cell(SpreadsheetSheetData sheet, int row, int col) {
    if (row < 1 || col < 1 || row > sheet.rows.length) return null;
    final cells = sheet.rows[row - 1];
    return col <= cells.length ? cells[col - 1] : null;
  }

  String _text(Object? value) => value?.toString().trim() ?? '';
  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s+'), ' ');
  int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(_text(value));
  int? _monthNumber(Object? value) {
    final numeric = _int(value);
    if (numeric != null && numeric >= 1 && numeric <= 12) return numeric;
    const months = [
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    final index = months.indexOf(_normalize(_text(value)));
    return index < 0 ? null : index + 1;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is num) {
      return DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    }
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  int? _minutes(Object? value) {
    if (value is Duration) return value.inMinutes;
    final text = _text(value);
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match != null) {
      return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    }
    final date = DateTime.tryParse(text);
    return date == null ? null : date.hour * 60 + date.minute;
  }

  bool _bool(Object? value) {
    if (value == true) return true;
    return [
      'да',
      'true',
      '1',
      'yes',
      '✓',
      'выполнено',
    ].contains(_normalize(_text(value)));
  }

  String _priority(String value) {
    switch (_normalize(value)) {
      case 'высокий':
        return 'high';
      case 'низкий':
        return 'low';
      default:
        return 'normal';
    }
  }

  String _status(String value) {
    final normalized = _normalize(value);
    if (normalized.contains('выполн')) return 'completed';
    if (normalized.contains('процесс')) return 'inProgress';
    if (normalized.contains('отмен')) return 'cancelled';
    return 'planned';
  }

  String _taskSignature(String title, DateTime? date) =>
      '${_normalize(title)}|${date == null ? '' : '${date.year}-${date.month}-${date.day}'}';
  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
