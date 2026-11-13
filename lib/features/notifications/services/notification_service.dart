import 'package:flutter/foundation.dart';

import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';
import 'notification_scheduler.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final NotificationRepository _repository = NotificationRepository();

  static const String _deliveryStatusKey = 'systemDeliveryStatus';

  static const String _deliveredStatus = 'delivered';

  /// Создаёт уведомление.
  ///
  /// Если eventKey уже существует, возвращает существующую запись.
  Future<NotificationItem> create({
    required NotificationCategory category,
    required String eventType,
    required String title,
    String message = '',
    NotificationType type = NotificationType.info,
    String? eventKey,
    String? sourceModule,
    String? sourceRecordId,
    DateTime? scheduledAt,
    Map<String, dynamic> metadata = const {},
  }) async {
    _validateEventKey(eventKey);

    if (eventKey != null) {
      final existing = await _repository.getByEventKey(eventKey);

      if (existing != null) return existing;
    }

    final notification = NotificationItem(
      id: _createId(),
      category: category,
      type: type,
      eventType: eventType,
      eventKey: eventKey,
      title: title,
      message: message,
      sourceModule: sourceModule,
      sourceRecordId: sourceRecordId,
      createdAt: DateTime.now(),
      scheduledAt: scheduledAt ?? DateTime.now(),
      metadata: metadata,
    );

    await _repository.create(notification);

    await NotificationScheduler.instance.checkNow();

    notifyListeners();

    return await _repository.getById(notification.id) ?? notification;
  }

  /// Создаёт или обновляет запланированное уведомление.
  ///
  /// При повторной синхронизации сохраняет ID записи,
  /// но обновляет дату, текст и метаданные доставки.
  Future<NotificationItem> schedule({
    required NotificationCategory category,
    required String eventType,
    required String title,
    required DateTime scheduledAt,
    String message = '',
    NotificationType type = NotificationType.reminder,
    String? eventKey,
    String? sourceModule,
    String? sourceRecordId,
    Map<String, dynamic> metadata = const {},
  }) async {
    _validateEventKey(eventKey);

    if (eventKey == null) {
      return create(
        category: category,
        eventType: eventType,
        title: title,
        message: message,
        type: type,
        sourceModule: sourceModule,
        sourceRecordId: sourceRecordId,
        scheduledAt: scheduledAt,
        metadata: metadata,
      );
    }

    final existing = await _repository.getByEventKey(eventKey);

    final updatedMetadata = <String, dynamic>{...metadata};

    late final NotificationItem notification;

    if (existing == null) {
      notification = NotificationItem(
        id: _createId(),
        category: category,
        type: type,
        eventType: eventType,
        eventKey: eventKey,
        title: title,
        message: message,
        sourceModule: sourceModule,
        sourceRecordId: sourceRecordId,
        createdAt: DateTime.now(),
        scheduledAt: scheduledAt,
        metadata: updatedMetadata,
      );

      await _repository.create(notification);
    } else {
      final wasDelivered =
          existing.metadata[_deliveryStatusKey] == _deliveredStatus;

      if (wasDelivered) {
        updatedMetadata.remove(_deliveryStatusKey);
        updatedMetadata.remove('systemDeliveredAt');
      }

      notification = NotificationItem(
        id: existing.id,
        category: category,
        type: type,
        eventType: eventType,
        eventKey: eventKey,
        title: title,
        message: message,
        sourceModule: sourceModule,
        sourceRecordId: sourceRecordId,
        createdAt: existing.createdAt,
        scheduledAt: scheduledAt,
        readAt: null,
        metadata: updatedMetadata,
      );

      await _repository.update(notification);
    }

    await NotificationScheduler.instance.checkNow();

    notifyListeners();

    return await _repository.getById(notification.id) ?? notification;
  }

  /// Отменяет ожидающее уведомление.
  ///
  /// Уже доставленные записи остаются в истории.
  Future<void> cancelScheduled(String eventKey) async {
    final existing = await _repository.getByEventKey(eventKey);

    if (existing == null) return;

    final isDelivered =
        existing.metadata[_deliveryStatusKey] == _deliveredStatus;

    if (isDelivered) return;

    await _repository.delete(existing.id);

    notifyListeners();
  }

  Future<void> cancelBySource({
    required String sourceModule,
    required String sourceRecordId,
  }) async {
    final notifications = await _repository.getAll(newestFirst: false);

    for (final notification in notifications) {
      if (notification.sourceModule != sourceModule ||
          notification.sourceRecordId != sourceRecordId) {
        continue;
      }

      final isDelivered =
          notification.metadata[_deliveryStatusKey] == _deliveredStatus;

      if (!isDelivered) {
        await _repository.delete(notification.id);
      }
    }

    notifyListeners();
  }

  Future<List<NotificationItem>> getAll({
    int? limit,
    int offset = 0,
    bool newestFirst = true,
  }) {
    return _repository.getAll(
      limit: limit,
      offset: offset,
      newestFirst: newestFirst,
    );
  }

  Future<List<NotificationItem>> getUnread({int? limit, int offset = 0}) {
    return _repository.getUnread(limit: limit, offset: offset);
  }

  Future<List<NotificationItem>> getPending() {
    return _repository.getPending();
  }

  Future<int> getUnreadCount() {
    return _repository.countUnread();
  }

  Future<int> getTotalCount() {
    return _repository.count();
  }

  Future<NotificationItem?> getById(String id) {
    return _repository.getById(id);
  }

  Future<NotificationItem?> getByEventKey(String eventKey) {
    return _repository.getByEventKey(eventKey);
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    notifyListeners();
  }

  Future<void> markUnread(String id) async {
    await _repository.markUnread(id);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    notifyListeners();
  }

  /// Очищает историю, не удаляя ожидающие напоминания.
  Future<void> clearHistory() async {
    await _repository.clear();
    notifyListeners();
  }

  Future<void> deleteOlderThan(DateTime date) async {
    await _repository.deleteOlderThan(date);
    notifyListeners();
  }

  void _validateEventKey(String? eventKey) {
    if (eventKey != null && eventKey.trim().isEmpty) {
      throw ArgumentError.value(
        eventKey,
        'eventKey',
        'Ключ события не может быть пустым.',
      );
    }
  }

  String _createId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
