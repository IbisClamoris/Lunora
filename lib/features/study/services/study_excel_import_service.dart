import 'package:lunora/core/import_export/models/spreadsheet_document.dart';
import 'package:lunora/features/study/models/study_item.dart';
import 'package:lunora/features/study/models/study_subject.dart';
import 'package:lunora/features/study/repositories/study_repository.dart';

class StudyExcelImportResult {
  final int subjects;
  final int periods;
  final int items;
  final int skippedSubjects;
  final int skippedPeriods;
  final int skippedItems;
  final int existingItems;

  const StudyExcelImportResult({
    required this.subjects,
    required this.periods,
    required this.items,
    required this.skippedSubjects,
    required this.skippedPeriods,
    required this.skippedItems,
    required this.existingItems,
  });

  int get totalImported => subjects + periods + items;

  int get totalSkipped => skippedSubjects + skippedPeriods + skippedItems;
}

class StudyExcelImportService {
  StudyExcelImportService._();

  static final StudyExcelImportService instance = StudyExcelImportService._();

  final StudyRepository _repository = StudyRepository.instance;

  Future<StudyExcelImportResult> importWorkbook(
    SpreadsheetDocument document,
  ) async {
    final sheets = <String, SpreadsheetSheetData>{
      for (final sheet in document.sheets) _normalize(sheet.name): sheet,
    };

    final subjectsSheet = sheets['предметы'] ?? sheets['учебные предметы'];

    final lecturesSheet = sheets['лекции'];
    final testsSheet = sheets['тесты'];
    final writtenSheet = sheets['письменные задания'];
    final sessionsSheet = sheets['сессии'] ?? sheets['сессия'];
    final practiceSheet = sheets['практика'];
    final courseworkSheet = sheets['курсовая'] ?? sheets['курсовая работа'];
    final diplomaSheet = sheets['диплом'] ?? sheets['дипломная работа'];

    final hasSupportedSheet =
        subjectsSheet != null ||
        lecturesSheet != null ||
        testsSheet != null ||
        writtenSheet != null ||
        sessionsSheet != null ||
        practiceSheet != null ||
        courseworkSheet != null ||
        diplomaSheet != null;

    if (!hasSupportedSheet) {
      throw Exception(
        'В книге не найдены поддерживаемые листы учебного планера: '
        '«Предметы», «Лекции», «Тесты», «Письменные задания», '
        '«Сессии», «Практика», «Курсовая» или «Диплом».',
      );
    }

    var importedSubjects = 0;
    var skippedSubjects = 0;
    var importedItems = 0;
    var skippedItems = 0;
    var alreadyExistingItems = 0;

    // В книге нет отдельного поля учебного года. Используем тот же расчёт,
    // что и StudyPage, чтобы импортированные предметы сразу отображались.
    final now = DateTime.now();
    final startYear = now.month >= 8 ? now.year : now.year - 1;
    final academicYear = '$startYear/${startYear + 1}';
    final semester = _readMainSemester(sheets['главная']) ?? 1;

    final existingSubjects = await _repository.getSubjects();
    final subjectMap = <String, StudySubject>{};

    for (final subject in existingSubjects) {
      final key = _normalize(subject.name);
      subjectMap.putIfAbsent(key, () => subject);
    }

    final assessmentTypes = <String, String>{};

    if (subjectsSheet != null) {
      final rows = _readRows(subjectsSheet, const [
        'Предмет',
        'Преподаватель',
        'Тип',
        'Статус',
        'Заметки',
      ]);

      for (final row in rows) {
        final name = _string(row, ['Предмет', 'Название предмета']);
        if (name.isEmpty) continue;

        final key = _normalize(name);
        final teacher = _string(row, ['Преподаватель', 'Учитель', 'Лектор']);
        final assessment = _string(row, ['Тип', 'Тип аттестации']);
        final sourceStatus = _string(row, ['Статус']);
        final sourceResult = _string(row, [
          'Заметки',
          'Результат',
          'Примечание',
        ]);

        if (assessment.isNotEmpty) {
          assessmentTypes[key] = assessment;
        }

        final description = _joinNonEmpty([
          if (assessment.isNotEmpty) 'Тип аттестации: $assessment',
          if (sourceStatus.isNotEmpty) 'Статус: $sourceStatus',
          if (sourceResult.isNotEmpty) 'Результат / заметки: $sourceResult',
        ]);

        final existingSubject = subjectMap[key];
        if (existingSubject != null) {
          // Предыдущая версия импортёра создавала предметы с пустым годом.
          // Исправляем их на месте, сохраняя ID и связи уже импортированных заданий.
          if (existingSubject.academicYear.trim().isEmpty) {
            final repairedSubject = existingSubject.copyWith(
              academicYear: academicYear,
              semester: semester,
              teacher: existingSubject.teacher.trim().isNotEmpty
                  ? existingSubject.teacher
                  : teacher,
              description: existingSubject.description.trim().isNotEmpty
                  ? existingSubject.description
                  : description,
            );
            await _repository.updateSubject(repairedSubject);
            subjectMap[key] = repairedSubject;
            importedSubjects++;
          } else {
            skippedSubjects++;
          }
          continue;
        }

        final subject = await _repository.createSubject(
          name: name,
          teacher: teacher,
          description: description,
          academicYear: academicYear,
          semester: semester,
          sortOrder: importedSubjects,
        );

        subjectMap[key] = subject;
        importedSubjects++;
      }
    }

    // Учитываем типы аттестации и для предметов, которые уже были в Lunora.
    if (subjectsSheet != null) {
      final rows = _readRows(subjectsSheet, const ['Предмет', 'Тип']);
      for (final row in rows) {
        final name = _string(row, ['Предмет', 'Название предмета']);
        final type = _string(row, ['Тип', 'Тип аттестации']);
        if (name.isNotEmpty && type.isNotEmpty) {
          assessmentTypes[_normalize(name)] = type;
        }
      }
    }

    final existingItems = await _repository.getItems();
    final itemSignatures = <String>{
      for (final item in existingItems)
        _itemSignature(
          title: item.title,
          subjectId: item.subjectId ?? '',
          type: item.type,
          scheduledAt: item.scheduledAt,
          dueAt: item.dueAt,
        ),
    };

    Future<void> importItem({
      required String title,
      required String subjectName,
      required StudyItemType type,
      String description = '',
      StudyItemFormat format = StudyItemFormat.none,
      StudyItemStatus status = StudyItemStatus.planned,
      DateTime? scheduledAt,
      DateTime? dueAt,
      String grade = '',
      String notes = '',
      int sortOrder = 0,
    }) async {
      if (title.trim().isEmpty) return;

      final subject = subjectName.trim().isEmpty
          ? null
          : subjectMap[_normalize(subjectName)];

      if (subjectName.trim().isNotEmpty && subject == null) {
        skippedItems++;
        return;
      }

      final signature = _itemSignature(
        title: title,
        subjectId: subject?.id ?? '',
        type: type,
        scheduledAt: scheduledAt,
        dueAt: dueAt,
      );

      if (!itemSignatures.add(signature)) {
        alreadyExistingItems++;
        return;
      }

      await _repository.createItem(
        subjectId: subject?.id,
        title: title.trim(),
        description: description.trim(),
        type: type,
        format: format,
        status: status,
        scheduledAt: scheduledAt,
        dueAt: dueAt,
        grade: grade.trim(),
        notes: notes.trim(),
        sortOrder: sortOrder,
      );

      importedItems++;
    }

    // ЛЕКЦИИ
    if (lecturesSheet != null) {
      final rows = _readRows(lecturesSheet, const [
        'Предмет',
        '№',
        'Тема',
        'Текст лекции',
        'Онлайн лекция',
        'Дата',
        'Статус',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final onlineValue = _string(row, ['Онлайн лекция']);
        final isOnline =
            onlineValue.isNotEmpty && !_normalize(onlineValue).contains('нет');

        final materialStatus = _string(row, ['Текст лекции']);
        final notes = _joinNonEmpty([
          if (materialStatus.isNotEmpty) 'Материал: $materialStatus',
          if (onlineValue.isNotEmpty) 'Онлайн-лекция: $onlineValue',
        ]);

        await importItem(
          title: _string(row, ['Тема', 'Название', 'Лекция']),
          subjectName: _string(row, ['Предмет', 'Название предмета']),
          type: isOnline ? StudyItemType.onlineLecture : StudyItemType.lecture,
          format: isOnline ? StudyItemFormat.online : StudyItemFormat.none,
          status: _itemStatus(_string(row, ['Статус'])),
          scheduledAt: _optionalDate(_value(row, ['Дата', 'Дата занятия'])),
          notes: notes,
          sortOrder: _integer(_value(row, ['№', 'Номер', 'Порядок'])) ?? index,
        );
      }
    }

    // ТЕСТЫ
    if (testsSheet != null) {
      final rows = _readRows(testsSheet, const [
        'Предмет',
        '№',
        'Тема',
        'Дедлайн',
        'Результат',
        'Статус',
        'Важность',
        'Заметки',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        await importItem(
          title: _string(row, ['Тема', 'Название', 'Тест']),
          subjectName: _string(row, ['Предмет', 'Название предмета']),
          type: StudyItemType.test,
          status: _itemStatus(_string(row, ['Статус'])),
          dueAt: _optionalDate(
            _value(row, ['Дедлайн', 'Срок выполнения', 'Дата сдачи']),
          ),
          grade: _string(row, ['Результат', 'Оценка', 'Балл']),
          notes: _joinNonEmpty([
            if (_string(row, ['Важность', 'Приоритет']).isNotEmpty)
              'Важность: ${_string(row, ['Важность', 'Приоритет'])}',
            _string(row, ['Заметки', 'Примечания']),
          ]),
          sortOrder: _integer(_value(row, ['№', 'Номер', 'Порядок'])) ?? index,
        );
      }
    }

    // ПИСЬМЕННЫЕ ЗАДАНИЯ
    if (writtenSheet != null) {
      final rows = _readRows(writtenSheet, const [
        'Предмет',
        'Задание',
        'Тема',
        'Дедлайн',
        'Результат',
        'Статус',
        'Важность',
        'Заметки',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        await importItem(
          title: _string(row, ['Задание', 'Название', 'Тип задания']),
          subjectName: _string(row, ['Предмет', 'Название предмета']),
          description: _string(row, ['Тема', 'Описание']),
          type: StudyItemType.writtenAssignment,
          status: _itemStatus(_string(row, ['Статус'])),
          dueAt: _optionalDate(
            _value(row, ['Дедлайн', 'Срок выполнения', 'Дата сдачи']),
          ),
          grade: _string(row, ['Результат', 'Оценка', 'Балл']),
          notes: _joinNonEmpty([
            if (_string(row, ['Важность', 'Приоритет']).isNotEmpty)
              'Важность: ${_string(row, ['Важность', 'Приоритет'])}',
            _string(row, ['Заметки', 'Примечания']),
          ]),
          sortOrder: index,
        );
      }
    }

    // СЕССИИ
    if (sessionsSheet != null) {
      final rows = _readRows(sessionsSheet, const [
        'Предмет',
        'Сессия',
        'Дата экзамена',
        'Формат',
        'Результат',
        'Статус',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final subjectName = _string(row, ['Предмет', 'Название предмета']);
        final assessment = assessmentTypes[_normalize(subjectName)] ?? '';
        final isCredit = _normalize(assessment).contains('зач');

        await importItem(
          title: _string(row, ['Сессия', 'Название']).isNotEmpty
              ? _string(row, ['Сессия', 'Название'])
              : (isCredit ? 'Зачёт' : 'Экзамен'),
          subjectName: subjectName,
          type: isCredit ? StudyItemType.credit : StudyItemType.exam,
          format: _itemFormat(_string(row, ['Формат'])),
          status: _itemStatus(_string(row, ['Статус'])),
          scheduledAt: _optionalDate(_value(row, ['Дата экзамена', 'Дата'])),
          grade: _string(row, ['Результат', 'Оценка']),
          sortOrder: index,
        );
      }
    }

    // ПРАКТИКА
    if (practiceSheet != null) {
      final rows = _readRows(practiceSheet, const [
        'Практика',
        'Период',
        'Задание',
        'Дедлайн',
        'Результат',
        'Статус',
        'Важность',
        'Заметки',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final practiceName = _string(row, ['Практика']);
        final periodName = _string(row, ['Период']);

        await importItem(
          title: _string(row, ['Задание', 'Название']),
          subjectName: '',
          description: _joinNonEmpty([
            if (practiceName.isNotEmpty) 'Практика: $practiceName',
            if (periodName.isNotEmpty) 'Период: $periodName',
          ]),
          type: StudyItemType.practice,
          status: _itemStatus(_string(row, ['Статус'])),
          dueAt: _optionalDate(_value(row, ['Дедлайн', 'Срок выполнения'])),
          grade: _string(row, ['Результат', 'Оценка']),
          notes: _joinNonEmpty([
            if (_string(row, ['Важность', 'Приоритет']).isNotEmpty)
              'Важность: ${_string(row, ['Важность', 'Приоритет'])}',
            _string(row, ['Заметки', 'Примечания']),
          ]),
          sortOrder: index,
        );
      }
    }

    // КУРСОВАЯ РАБОТА
    if (courseworkSheet != null) {
      final rows = _readRows(courseworkSheet, const [
        'Этап',
        'Задача',
        'Дедлайн',
        'Дата выполнения',
        'Статус',
        'Заметки',
        'Важность',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        await importItem(
          title: _string(row, ['Задача', 'Название']),
          subjectName: '',
          description: _string(row, ['Этап']),
          type: StudyItemType.coursework,
          status: _itemStatus(_string(row, ['Статус'])),
          scheduledAt: _optionalDate(_value(row, ['Дата выполнения'])),
          dueAt: _optionalDate(_value(row, ['Дедлайн', 'Срок выполнения'])),
          notes: _joinNonEmpty([
            if (_string(row, ['Важность', 'Приоритет']).isNotEmpty)
              'Важность: ${_string(row, ['Важность', 'Приоритет'])}',
            _string(row, ['Заметки', 'Примечания']),
          ]),
          sortOrder: index,
        );
      }
    }

    // ДИПЛОМНАЯ РАБОТА
    if (diplomaSheet != null) {
      final rows = _readRows(diplomaSheet, const [
        'Этап',
        'Задача',
        'Дедлайн',
        'Дата выполнения',
        'Статус',
        'Заметки',
        'Важность',
      ]);

      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        await importItem(
          title: _string(row, ['Задача', 'Название']),
          subjectName: '',
          description: _string(row, ['Этап']),
          type: StudyItemType.diploma,
          status: _itemStatus(_string(row, ['Статус'])),
          scheduledAt: _optionalDate(_value(row, ['Дата выполнения'])),
          dueAt: _optionalDate(_value(row, ['Дедлайн', 'Срок выполнения'])),
          notes: _joinNonEmpty([
            if (_string(row, ['Важность', 'Приоритет']).isNotEmpty)
              'Важность: ${_string(row, ['Важность', 'Приоритет'])}',
            _string(row, ['Заметки', 'Примечания']),
          ]),
          sortOrder: index,
        );
      }
    }

    return StudyExcelImportResult(
      subjects: importedSubjects,
      periods: 0,
      items: importedItems,
      skippedSubjects: skippedSubjects,
      skippedPeriods: 0,
      skippedItems: skippedItems,
      existingItems: alreadyExistingItems,
    );
  }

  static List<Map<String, Object?>> _readRows(
    SpreadsheetSheetData sheet,
    List<String> expectedHeaders,
  ) {
    if (sheet.rows.isEmpty) return [];

    final expected = expectedHeaders.map(_normalize).toSet();
    var headerIndex = -1;
    var bestScore = 0;

    // В книге заголовки расположены на четвёртой строке.
    // Поиск по содержимому оставляет импорт совместимым и с обычными таблицами.
    final scanLimit = sheet.rows.length < 12 ? sheet.rows.length : 12;

    for (var rowIndex = 0; rowIndex < scanLimit; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final score = row
          .map((value) => _normalize(value?.toString() ?? ''))
          .where((value) => expected.contains(value))
          .length;

      if (score > bestScore) {
        bestScore = score;
        headerIndex = rowIndex;
      }
    }

    if (headerIndex < 0 || bestScore < 2) return [];

    final headers = sheet.rows[headerIndex]
        .map((value) => _normalize(value?.toString() ?? ''))
        .toList();

    final result = <Map<String, Object?>>[];

    for (final row in sheet.rows.skip(headerIndex + 1)) {
      final values = <String, Object?>{};

      for (var column = 0; column < headers.length; column++) {
        final header = headers[column];
        if (header.isEmpty) continue;

        values[header] = column < row.length ? row[column] : null;
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

  static Object? _value(Map<String, Object?> row, List<String> names) {
    for (final name in names) {
      final key = _normalize(name);
      if (row.containsKey(key)) return row[key];
    }
    return null;
  }

  static String _string(Map<String, Object?> row, List<String> names) {
    final value = _value(row, names);
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int? _readMainSemester(SpreadsheetSheetData? sheet) {
    if (sheet == null || sheet.rows.length < 2) return null;
    final row = sheet.rows[1];
    if (row.length < 4) return null;
    return _integer(row[3]);
  }

  static int? _integer(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9\-]'), ''));
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _parseDate(value);
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is num) {
      final milliseconds = (value * Duration.millisecondsPerDay).round();
      return DateTime(1899, 12, 30).add(Duration(milliseconds: milliseconds));
    }

    final text = value.toString().trim();
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(text);

    if (match != null) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }

    throw FormatException('Не удалось распознать дату: $value');
  }

  static StudyItemStatus _itemStatus(String value) {
    final text = _normalize(value);

    if (text.contains('отмен') || text == 'cancelled') {
      return StudyItemStatus.cancelled;
    }

    if (text.contains('в процесс') ||
        text.contains('в работе') ||
        text.contains('выполняется') ||
        text == 'inprogress') {
      return StudyItemStatus.inProgress;
    }

    if (text.contains('сдан') ||
        text.contains('заверш') ||
        text.contains('выполн') ||
        text.contains('прочитан') ||
        text == 'completed') {
      return StudyItemStatus.completed;
    }

    return StudyItemStatus.planned;
  }

  static StudyItemFormat _itemFormat(String value) {
    final text = _normalize(value);

    if (text.contains('онлайн') || text == 'online') {
      return StudyItemFormat.online;
    }

    if (text.contains('очно') ||
        text.contains('аудитор') ||
        text == 'offline') {
      return StudyItemFormat.offline;
    }

    return StudyItemFormat.none;
  }

  static String _joinNonEmpty(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
  }

  static String _itemSignature({
    required String title,
    required String subjectId,
    required StudyItemType type,
    required DateTime? scheduledAt,
    required DateTime? dueAt,
  }) {
    return [
      _normalize(title),
      subjectId,
      type.name,
      scheduledAt?.toIso8601String() ?? '',
      dueAt?.toIso8601String() ?? '',
    ].join('|');
  }
}
