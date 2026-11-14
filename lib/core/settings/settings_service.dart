import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database.dart';
import 'app_settings.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    final db = await LunoraDatabase.instance.database;
    final rows = await db.query('settings');

    final values = <String, String>{};

    for (final row in rows) {
      final key = row['setting_key'] as String;
      final value = row['setting_value'] as String?;

      if (value != null) {
        values[key] = value;
      }
    }

    _settings = _fromMap(values);
    notifyListeners();
  }

  Future<void> save() async {
    final db = await LunoraDatabase.instance.database;
    final values = _toMap(_settings);

    await db.transaction((txn) async {
      for (final entry in values.entries) {
        await txn.insert('settings', {
          'setting_key': entry.key,
          'setting_value': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> update(AppSettings newSettings) async {
    _settings = newSettings;
    await save();
    notifyListeners();
  }

  Future<void> reset() async {
    _settings = const AppSettings();
    await save();
    notifyListeners();
  }

  Map<String, String> _toMap(AppSettings settings) {
    return {
      'themeMode': settings.themeMode.name,
      'language': settings.language.name,
      'density': settings.density.name,
      'colorTheme': settings.colorTheme.name,
      'currency': settings.currency,
      'dateFormat': settings.dateFormat,
      'use24HourTime': settings.use24HourTime.toString(),
      'firstDayMonday': settings.firstDayMonday.toString(),
      'notificationsEnabled': settings.notificationsEnabled.toString(),
      'soundEnabled': settings.soundEnabled.toString(),
      'notificationVolume': settings.notificationVolume.toString(),
      'quietHoursEnabled': settings.quietHoursEnabled.toString(),
      'quietHoursStart': settings.quietHoursStart,
      'quietHoursEnd': settings.quietHoursEnd,
      'startWithWindows': settings.startWithWindows.toString(),
      'checkForUpdatesAutomatically': settings.checkForUpdatesAutomatically.toString(),
      'minimizeToTray': settings.minimizeToTray.toString(),
      'botanicalDecorations': settings.botanicalDecorations.toString(),
      'animationsEnabled': settings.animationsEnabled.toString(),
      'sectionVisibility': jsonEncode(settings.sectionVisibility),
    };
  }

  AppSettings _fromMap(Map<String, String> values) {
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (value) => value.name == values['themeMode'],
        orElse: () => AppThemeMode.light,
      ),
      language: AppLanguage.values.firstWhere(
        (value) => value.name == values['language'],
        orElse: () => AppLanguage.russian,
      ),
      density: AppDensity.values.firstWhere(
        (value) => value.name == values['density'],
        orElse: () => AppDensity.comfortable,
      ),
      colorTheme: AppColorTheme.values.firstWhere(
        (value) => value.name == values['colorTheme'],
        orElse: () => AppColorTheme.botanical,
      ),
      currency: values['currency'] ?? 'RUB',
      dateFormat: values['dateFormat'] ?? 'dd.MM.yyyy',
      use24HourTime: _bool(values, 'use24HourTime', true),
      firstDayMonday: _bool(values, 'firstDayMonday', true),
      notificationsEnabled: _bool(values, 'notificationsEnabled', true),
      soundEnabled: _bool(values, 'soundEnabled', true),
      notificationVolume:
          int.tryParse(values['notificationVolume'] ?? '') ?? 70,
      quietHoursEnabled: _bool(values, 'quietHoursEnabled', false),
      quietHoursStart: values['quietHoursStart'] ?? '23:00',
      quietHoursEnd: values['quietHoursEnd'] ?? '08:00',
      startWithWindows: _bool(values, 'startWithWindows', false),
      checkForUpdatesAutomatically: _bool(values, 'checkForUpdatesAutomatically', true),
      minimizeToTray: _bool(values, 'minimizeToTray', true),
      botanicalDecorations: _bool(values, 'botanicalDecorations', true),
      animationsEnabled: _bool(values, 'animationsEnabled', true),
      sectionVisibility: _decodeSectionVisibility(values['sectionVisibility']),
    );
  }

  Map<String, bool> _decodeSectionVisibility(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((key, value) => MapEntry(key, value == true));
      }
    } catch (_) {
      return const {};
    }
    return const {};
  }

  bool _bool(Map<String, String> values, String key, bool defaultValue) {
    return values[key] == null ? defaultValue : values[key] == 'true';
  }
}
