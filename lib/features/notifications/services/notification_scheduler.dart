import 'dart:async';

import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/repositories/notification_repository.dart';
import 'package:lunora/features/notifications/services/system_notification_service.dart';
import 'package:lunora/core/settings/settings_service.dart';

class NotificationScheduler {
  NotificationScheduler._();

  static final NotificationScheduler instance = NotificationScheduler._();

  static const Duration checkInterval = Duration(seconds: 15);

  static const String deliveryStatusKey = 'systemDeliveryStatus';
  static const String deliveredAtKey = 'systemDeliveredAt';

  static const String deliveredStatus = 'delivered';

  final NotificationRepository _repository = NotificationRepository();

  final SystemNotificationService _systemNotifications =
      SystemNotificationService.instance;

  Timer? _timer;

  bool _isChecking = false;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (_timer != null) return;

    await _systemNotifications.initialize();

    _timer = Timer.periodic(checkInterval, (_) {
      unawaited(checkNow());
    });

    await checkNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    if (_isChecking) return;

    _isChecking = true;

    try {
      final settings = SettingsService.instance.settings;

      // Отключение уведомлений не удаляет очередь.
      if (!settings.notificationsEnabled) return;

      final now = DateTime.now();

      // Загружаем только ожидающие уведомления.
      final notifications = await _repository.getPending();

      for (final notification in notifications) {
        var current = notification;
        final eventType = current.eventType;
        final supportsSmartTiming = eventType == 'task_due' ||
            eventType == 'study_session' ||
            eventType == 'study_deadline';
        final eventAt = DateTime.tryParse(
          current.metadata['eventAt']?.toString() ?? '',
        );

        // Изменение времени в настройках применяется и к уже созданным
        // напоминаниям, а не только к новым задачам и занятиям.
        if (supportsSmartTiming &&
            eventAt != null &&
            current.metadata['leadTimeMinutes'] !=
                settings.reminderLeadTimeMinutes) {
          final metadata = Map<String, dynamic>.from(current.metadata)
            ..['leadTimeMinutes'] = settings.reminderLeadTimeMinutes;
          final leadMinutes = settings.reminderLeadTimeMinutes;
          final updatedMessage = current.message
              .replaceAll(RegExp(r'\\d+ минут'), '$leadMinutes минут')
              .replaceAll(RegExp(r'\\d+ minutes'), '$leadMinutes minutes');
          current = current.copyWith(
            scheduledAt: eventAt.subtract(Duration(minutes: leadMinutes)),
            message: updatedMessage,
            metadata: metadata,
          );
          await _repository.update(current);
        }

        final scheduledAt = current.scheduledAt;

        if (scheduledAt == null || scheduledAt.isAfter(now)) {
          continue;
        }

        final status = current.metadata[deliveryStatusKey];

        if (status == deliveredStatus) {
          continue;
        }

        // Во время тихих часов оставляем уведомление в очереди.
        if (_systemNotifications.isQuietHoursNow(now)) {
          break;
        }

        try {
          final shown = await _systemNotifications.showNow(current);

          if (!shown) continue;

          await _updateDeliveryStatus(
            current,
            deliveredAt: DateTime.now(),
          );
        } catch (error) {
          // Ошибка доставки не удаляет уведомление.
          // Следующая проверка повторит попытку.
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _updateDeliveryStatus(
    NotificationItem notification, {
    required DateTime deliveredAt,
  }) async {
    final metadata = Map<String, dynamic>.from(notification.metadata);

    metadata[deliveryStatusKey] = deliveredStatus;
    metadata[deliveredAtKey] = deliveredAt.toIso8601String();

    await _repository.update(notification.copyWith(metadata: metadata));
  }
}
