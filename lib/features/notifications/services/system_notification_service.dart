import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/core/settings/settings_service.dart';

class SystemNotificationService {
  SystemNotificationService._();

  static final SystemNotificationService instance =
      SystemNotificationService._();

  static const String appUserModelId = 'com.example.Lunora.Desktop';

  static const String notificationGuid = 'c2a1f5e8-7d34-4b91-a6c2-83f0d9e14752';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  bool _initialized = false;

  Future<void>? _initializationFuture;

  String? _launchPayload;

  bool get isInitialized => _initialized;

  Stream<String> get onNotificationTap => _notificationTapController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    final existingInitialization = _initializationFuture;

    if (existingInitialization != null) {
      await existingInitialization;
      return;
    }

    final initialization = _initializeInternal();

    _initializationFuture = initialization;

    try {
      await initialization;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    const initializationSettings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'Lunora',
        appUserModelId: appUserModelId,
        guid: notificationGuid,
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _initialized = true;

    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();

      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;

        if (payload != null && payload.isNotEmpty) {
          _launchPayload = payload;
        }
      }
    } catch (error) {
      // Ошибка получения данных запуска не мешает
      // обычной работе системных уведомлений.
    }
  }

  /// Возвращает ID уведомления, запустившего приложение.
  /// Значение выдаётся только один раз.
  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) return;

    if (!_notificationTapController.isClosed) {
      _notificationTapController.add(payload);
    }
  }

  Future<bool> showNow(NotificationItem notification) async {
    await initialize();

    final settings = SettingsService.instance.settings;

    if (!settings.notificationsEnabled) {
      return false;
    }

    if (isQuietHoursNow()) {
      return false;
    }

    final audio = settings.soundEnabled
        ? null
        : WindowsNotificationAudio.silent();

    await _plugin.show(
      id: _notificationId(notification.id),
      title: LunoraLocalization.text(notification.title),
      body: LunoraLocalization.text(notification.message),
      payload: notification.id,
      notificationDetails: NotificationDetails(
        windows: WindowsNotificationDetails(audio: audio),
      ),
    );

    return true;
  }

  bool isQuietHoursNow([DateTime? dateTime]) {
    final settings = SettingsService.instance.settings;

    if (!settings.quietHoursEnabled) {
      return false;
    }

    final start = _parseTime(settings.quietHoursStart);
    final end = _parseTime(settings.quietHoursEnd);

    if (start == null || end == null || start == end) {
      return false;
    }

    final now = dateTime ?? DateTime.now();

    final currentMinutes = now.hour * 60 + now.minute;

    if (start < end) {
      return currentMinutes >= start && currentMinutes < end;
    }

    // Тихие часы переходят через полночь.
    return currentMinutes >= start || currentMinutes < end;
  }

  int? _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);

    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        hours > 23 ||
        minutes < 0 ||
        minutes > 59) {
      return null;
    }

    return hours * 60 + minutes;
  }

  int _notificationId(String value) {
    var hash = 0x811C9DC5;

    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }

    return hash == 0 ? 1 : hash;
  }

  /// Освобождает состояние сервиса.
  ///
  /// Поток нажатий не закрываем: сервис можно
  /// инициализировать повторно.
  Future<void> dispose() async {
    _initialized = false;
    _launchPayload = null;
  }
}
