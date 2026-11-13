import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';

import '../models/task.dart';

class TaskRepository {
  TaskRepository._();

  static final TaskRepository instance = TaskRepository._();

  static const Duration _reminderLeadTime = Duration(minutes: 15);

  static const String _eventKeyPrefix = 'task_due_';
  static const String _sourceModule = 'tasks';

  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  Future<List<Task>> getAll() async {
    final db = await _database;

    final rows = await db.query(
      'tasks',
      orderBy: 'due_date ASC, due_time_minutes ASC, created_at DESC',
    );

    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getById(String id) async {
    final db = await _database;

    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Task.fromMap(rows.first);
  }

  Future<Task> create(Task task) async {
    final db = await _database;

    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    await _syncReminder(task);

    return task;
  }

  Future<void> update(Task task) async {
    final db = await _database;

    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    await _syncReminder(task);
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);

    await NotificationService.instance.cancelBySource(
      sourceModule: _sourceModule,
      sourceRecordId: id,
    );
  }

  Future<void> _syncReminder(Task task) async {
    final notificationService = NotificationService.instance;
    final eventKey = '$_eventKeyPrefix${task.id}';

    final isActive =
        task.status != TaskStatus.completed &&
        task.status != TaskStatus.cancelled;

    final dueDate = task.dueDate;
    final dueTimeMinutes = task.dueTimeMinutes;

    if (!isActive || dueDate == null || dueTimeMinutes == null) {
      await notificationService.cancelScheduled(eventKey);
      return;
    }

    final eventAt = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueTimeMinutes ~/ 60,
      dueTimeMinutes % 60,
    );

    if (!eventAt.isAfter(DateTime.now())) {
      await notificationService.cancelScheduled(eventKey);
      return;
    }

    final reminderAt = eventAt.subtract(_reminderLeadTime);

    final existing = await notificationService.getByEventKey(eventKey);

    final wasDelivered =
        existing?.metadata['systemDeliveryStatus'] == 'delivered';

    // Не отправляем повторно уже доставленное напоминание,
    // если время задачи не изменилось.
    if (wasDelivered && existing?.scheduledAt == reminderAt) {
      return;
    }

    await notificationService.schedule(
      category: NotificationCategory.tasks,
      type: NotificationType.reminder,
      eventType: 'task_due',
      eventKey: eventKey,
      title: LunoraLocalization.text('Скоро срок задачи', 'Task due soon'),
      message: LunoraLocalization.text(
        'Задача «${task.title}» наступит через 15 минут.',
      ),
      sourceModule: _sourceModule,
      sourceRecordId: task.id,
      scheduledAt: reminderAt,
      metadata: {'eventAt': eventAt.toIso8601String()},
    );
  }
}
