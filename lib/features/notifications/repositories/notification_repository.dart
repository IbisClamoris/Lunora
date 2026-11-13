import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lunora/core/database/database.dart';

import '../models/notification_item.dart';

class NotificationRepository {
  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  static const String _deliveryStatusKey = 'systemDeliveryStatus';

  static const String _deliveredStatus = 'delivered';

  Future<void> create(NotificationItem notification) async {
    final db = await _database;

    await db.insert(
      'notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<NotificationItem?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return NotificationItem.fromMap(result.first);
  }

  Future<NotificationItem?> getByEventKey(String eventKey) async {
    final db = await _database;

    final result = await db.query(
      'notifications',
      where: 'event_key = ?',
      whereArgs: [eventKey],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return NotificationItem.fromMap(result.first);
  }

  Future<List<NotificationItem>> getAll({
    int? limit,
    int offset = 0,
    bool newestFirst = true,
  }) async {
    final db = await _database;

    final result = await db.query(
      'notifications',
      orderBy: newestFirst ? 'created_at DESC' : 'created_at ASC',
      limit: limit,
      offset: offset,
    );

    return result.map(NotificationItem.fromMap).toList();
  }

  Future<List<NotificationItem>> getUnread({int? limit, int offset = 0}) async {
    final db = await _database;

    final result = await db.query(
      'notifications',
      where: 'read_at IS NULL',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(NotificationItem.fromMap).toList();
  }

  Future<List<NotificationItem>> getPending() async {
    final db = await _database;

    final result = await db.query(
      'notifications',
      where: 'scheduled_at IS NOT NULL',
      orderBy: 'scheduled_at ASC',
    );

    return result.map(NotificationItem.fromMap).where((item) {
      return item.metadata[_deliveryStatusKey] != _deliveredStatus;
    }).toList();
  }

  Future<void> update(NotificationItem notification) async {
    final db = await _database;

    await db.update(
      'notifications',
      notification.toMap(),
      where: 'id = ?',
      whereArgs: [notification.id],
    );
  }

  Future<void> markRead(String id) async {
    final db = await _database;

    await db.update(
      'notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markUnread(String id) async {
    final db = await _database;

    await db.update(
      'notifications',
      {'read_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final db = await _database;

    await db.update('notifications', {
      'read_at': DateTime.now().toIso8601String(),
    }, where: 'read_at IS NULL');
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  /// Очищает историю, сохраняя ожидающие напоминания.
  Future<void> clear() async {
    final notifications = await getAll(newestFirst: false);

    for (final notification in notifications) {
      final isPending =
          notification.scheduledAt != null &&
          notification.metadata[_deliveryStatusKey] != _deliveredStatus;

      if (!isPending) {
        await delete(notification.id);
      }
    }
  }

  /// Удаляет старые записи, не затрагивая ожидающие напоминания.
  Future<void> deleteOlderThan(DateTime date) async {
    final notifications = await getAll(newestFirst: false);

    for (final notification in notifications) {
      final isPending =
          notification.scheduledAt != null &&
          notification.metadata[_deliveryStatusKey] != _deliveredStatus;

      if (!isPending && notification.createdAt.isBefore(date)) {
        await delete(notification.id);
      }
    }
  }

  Future<int> countUnread() async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM notifications WHERE read_at IS NULL',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> count() async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM notifications',
    );

    return (result.first['total'] as int?) ?? 0;
  }
}
