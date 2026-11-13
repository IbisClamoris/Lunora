import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';

import '../models/study_subject.dart';
import '../models/study_period.dart';
import '../models/study_item.dart';

typedef StudyDatabaseProvider = Future<Database> Function();

class StudyRepository {
  StudyRepository._({StudyDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final StudyRepository instance = StudyRepository._();

  factory StudyRepository.forTesting(StudyDatabaseProvider databaseProvider) {
    return StudyRepository._(databaseProvider: databaseProvider);
  }

  final StudyDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();

  Future<Database> get _db => _databaseProvider();

  String _newId() => _uuid.v4();

  // ============================================================
  // ПРЕДМЕТЫ
  // ============================================================

  Future<StudySubject> createSubject({
    required String name,
    String teacher = '',
    String description = '',
    String academicYear = '',
    int semester = 1,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();

    final subject = StudySubject(
      id: _newId(),
      name: name.trim(),
      teacher: teacher.trim(),
      description: description.trim(),
      academicYear: academicYear,
      semester: semester,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('study_subjects', subject.toMap());

    return subject;
  }

  Future<StudySubject?> getSubjectById(String id) async {
    final db = await _db;

    final result = await db.query(
      'study_subjects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return StudySubject.fromMap(result.first);
  }

  Future<List<StudySubject>> getSubjects({
    String? academicYear,
    int? semester,
    String? searchQuery,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (academicYear != null && academicYear.isNotEmpty) {
      conditions.add('academic_year = ?');
      arguments.add(academicYear);
    }

    if (semester != null) {
      conditions.add('semester = ?');
      arguments.add(semester);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('name LIKE ?');
      arguments.add('%${searchQuery.trim()}%');
    }

    final result = await db.query(
      'study_subjects',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );

    return result.map(StudySubject.fromMap).toList();
  }

  Future<void> updateSubject(StudySubject subject) async {
    final db = await _db;

    final updated = subject.copyWith(updatedAt: DateTime.now());

    await db.update(
      'study_subjects',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> deleteSubject(String id) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.update(
        'study_items',
        {'subject_id': null},
        where: 'subject_id = ?',
        whereArgs: [id],
      );

      await txn.delete('study_subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ============================================================
  // УЧЕБНЫЕ ПЕРИОДЫ
  // ============================================================

  Future<StudyPeriod> createPeriod({
    required String title,
    required StudyPeriodType type,
    required String academicYear,
    int semester = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    String description = '',
  }) async {
    final now = DateTime.now();

    final period = StudyPeriod(
      id: _newId(),
      title: title.trim(),
      type: type,
      academicYear: academicYear,
      semester: semester,
      startsAt: startsAt,
      endsAt: endsAt,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('study_periods', period.toMap());

    return period;
  }

  Future<StudyPeriod?> getPeriodById(String id) async {
    final db = await _db;

    final result = await db.query(
      'study_periods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return StudyPeriod.fromMap(result.first);
  }

  Future<List<StudyPeriod>> getPeriods({
    String? academicYear,
    StudyPeriodType? type,
    int? semester,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (academicYear != null && academicYear.isNotEmpty) {
      conditions.add('academic_year = ?');
      arguments.add(academicYear);
    }

    if (type != null) {
      conditions.add('period_type = ?');
      arguments.add(type.name);
    }

    if (semester != null) {
      conditions.add('semester = ?');
      arguments.add(semester);
    }

    final result = await db.query(
      'study_periods',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'starts_at IS NULL ASC, starts_at ASC, title ASC',
    );

    return result.map(StudyPeriod.fromMap).toList();
  }

  Future<void> updatePeriod(StudyPeriod period) async {
    final db = await _db;

    final updated = period.copyWith(updatedAt: DateTime.now());

    await db.update(
      'study_periods',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [period.id],
    );
  }

  Future<void> deletePeriod(String id) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.update(
        'study_items',
        {'period_id': null},
        where: 'period_id = ?',
        whereArgs: [id],
      );

      await txn.delete('study_periods', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ============================================================
  // УЧЕБНЫЕ СОБЫТИЯ
  // ============================================================

  Future<StudyItem> createItem({
    String? subjectId,
    String? periodId,
    required String title,
    String description = '',
    required StudyItemType type,
    StudyItemFormat format = StudyItemFormat.none,
    StudyItemStatus status = StudyItemStatus.planned,
    DateTime? scheduledAt,
    DateTime? dueAt,
    String grade = '',
    String notes = '',
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();

    final item = StudyItem(
      id: _newId(),
      subjectId: subjectId,
      periodId: periodId,
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
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('study_items', item.toMap());

    await _syncItemReminders(item);

    return item;
  }

  Future<StudyItem?> getItemById(String id) async {
    final db = await _db;

    final result = await db.query(
      'study_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return StudyItem.fromMap(result.first);
  }

  Future<List<StudyItem>> getItems({
    String? subjectId,
    String? periodId,
    StudyItemType? type,
    StudyItemStatus? status,
    String? searchQuery,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (subjectId != null) {
      conditions.add('subject_id = ?');
      arguments.add(subjectId);
    }

    if (periodId != null) {
      conditions.add('period_id = ?');
      arguments.add(periodId);
    }

    if (type != null) {
      conditions.add('item_type = ?');
      arguments.add(type.name);
    }

    if (status != null) {
      conditions.add('status = ?');
      arguments.add(status.name);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR description LIKE ?)');
      final query = '%${searchQuery.trim()}%';
      arguments.addAll([query, query]);
    }

    final result = await db.query(
      'study_items',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: '''
        scheduled_at IS NULL ASC,
        scheduled_at ASC,
        due_at IS NULL ASC,
        due_at ASC,
        sort_order ASC
      ''',
    );

    return result.map(StudyItem.fromMap).toList();
  }

  Future<void> updateItem(StudyItem item) async {
    final db = await _db;

    final updated = item.copyWith(updatedAt: DateTime.now());

    await db.update(
      'study_items',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );

    await _syncItemReminders(updated);
  }

  Future<void> deleteItem(String id) async {
    final db = await _db;

    await db.delete('study_items', where: 'id = ?', whereArgs: [id]);

    await NotificationService.instance.cancelBySource(
      sourceModule: 'study_planner',
      sourceRecordId: id,
    );
  }

  // ============================================================
  // СИНХРОНИЗАЦИЯ УВЕДОМЛЕНИЙ
  // ============================================================

  Future<void> _syncItemReminders(StudyItem item) async {
    final service = NotificationService.instance;

    final isActive =
        item.status != StudyItemStatus.completed &&
        item.status != StudyItemStatus.cancelled;

    if (!isActive) {
      await service.cancelScheduled('study_session_${item.id}');

      await service.cancelScheduled('study_deadline_${item.id}');

      return;
    }

    await _syncStudyReminder(
      item: item,
      eventAt: item.scheduledAt,
      eventKey: 'study_session_${item.id}',
      eventType: 'study_session',
      title: LunoraLocalization.text(
        'Скоро начнётся занятие',
        'Class starting soon',
      ),
      message: LunoraLocalization.text(
        'Занятие «${item.title}» начнётся через 15 минут.',
      ),
    );

    await _syncStudyReminder(
      item: item,
      eventAt: item.dueAt,
      eventKey: 'study_deadline_${item.id}',
      eventType: 'study_deadline',
      title: LunoraLocalization.text('Скоро дедлайн', 'Deadline approaching'),
      message: LunoraLocalization.text(
        'Срок выполнения «${item.title}» наступит через 15 минут.',
      ),
    );
  }

  Future<void> _syncStudyReminder({
    required StudyItem item,
    required DateTime? eventAt,
    required String eventKey,
    required String eventType,
    required String title,
    required String message,
  }) async {
    final service = NotificationService.instance;

    if (eventAt == null || !eventAt.isAfter(DateTime.now())) {
      await service.cancelScheduled(eventKey);
      return;
    }

    final reminderAt = eventAt.subtract(const Duration(minutes: 15));

    final existing = await service.getByEventKey(eventKey);

    final wasDelivered =
        existing?.metadata['systemDeliveryStatus'] == 'delivered';

    if (wasDelivered && existing?.scheduledAt == reminderAt) {
      return;
    }

    await service.schedule(
      category: NotificationCategory.study,
      type: NotificationType.reminder,
      eventType: eventType,
      eventKey: eventKey,
      title: title,
      message: message,
      sourceModule: 'study_planner',
      sourceRecordId: item.id,
      scheduledAt: reminderAt,
      metadata: {
        'eventAt': eventAt.toIso8601String(),
        'studyItemType': item.type.name,
      },
    );
  }

  // ============================================================
  // СТАТИСТИКА
  // ============================================================

  Future<int> countSubjects({String? academicYear}) async {
    final db = await _db;

    final result = await db.rawQuery(
      academicYear == null
          ? 'SELECT COUNT(*) AS total FROM study_subjects'
          : '''
            SELECT COUNT(*) AS total
            FROM study_subjects
            WHERE academic_year = ?
          ''',
      academicYear == null ? null : [academicYear],
    );

    return result.first['total'] as int? ?? 0;
  }

  Future<int> countItems({StudyItemStatus? status}) async {
    final db = await _db;

    final result = await db.rawQuery(
      status == null
          ? 'SELECT COUNT(*) AS total FROM study_items'
          : '''
            SELECT COUNT(*) AS total
            FROM study_items
            WHERE status = ?
          ''',
      status == null ? null : [status.name],
    );

    return result.first['total'] as int? ?? 0;
  }
}
