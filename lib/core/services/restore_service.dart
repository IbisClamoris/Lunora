import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/storage/storage_service.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';
import 'package:lunora/shared/models/backup_info.dart';

class RestoreService {
  RestoreService._();

  static final RestoreService instance = RestoreService._();
  static const Uuid _uuid = Uuid();

  bool _isRestoring = false;

  Future<void> restoreBackup(BackupInfo backup) async {
    if (_isRestoring) {
      throw Exception('Восстановление уже выполняется.');
    }

    _isRestoring = true;

    File? temporaryFile;
    var databaseClosed = false;

    try {
      final sourceFile = File(backup.filePath);

      if (!await sourceFile.exists() ||
          p.extension(sourceFile.path).toLowerCase() != '.db') {
        throw Exception('Файл резервной копии не найден.');
      }

      await _validateDatabase(sourceFile.path);

      final database = await LunoraDatabase.instance.database;
      final databasePath = database.path;

      if (p.equals(
        p.normalize(p.absolute(sourceFile.path)),
        p.normalize(p.absolute(databasePath)),
      )) {
        throw Exception('Нельзя восстановить базу из её собственного файла.');
      }

      final dataDirectory = await StorageService.instance.dataDirectory;

      temporaryFile = File(
        p.join(dataDirectory.path, 'lunora_restore_${_uuid.v4()}.tmp.db'),
      );

      await sourceFile.copy(temporaryFile.path);
      await _validateDatabase(temporaryFile.path);

      final checkpoint = await database.rawQuery(
        'PRAGMA wal_checkpoint(TRUNCATE)',
      );

      if (checkpoint.isEmpty || checkpoint.first['busy'] != 0) {
        throw Exception('Не удалось подготовить базу к восстановлению.');
      }

      await LunoraDatabase.instance.close();
      databaseClosed = true;

      final backupDirectory = await StorageService.instance.backupsDirectory;

      final now = DateTime.now();
      final safetyName =
          'lunora_before_restore_${_timestamp(now)}_${_uuid.v4().substring(0, 8)}.db';

      final safetyFile = File(p.join(backupDirectory.path, safetyName));

      final currentFile = File(databasePath);

      await currentFile.copy(safetyFile.path);

      if (!await safetyFile.exists() || await safetyFile.length() == 0) {
        throw Exception('Не удалось создать страховочную копию текущей базы.');
      }

      await _deleteSidecars(databasePath);

      try {
        await temporaryFile.copy(databasePath);
        await _validateDatabase(databasePath);
      } catch (restoreError) {
        try {
          await _deleteSidecars(databasePath);
          await safetyFile.copy(databasePath);
          await _validateDatabase(databasePath);
        } catch (rollbackError) {
          throw Exception(
            'Восстановление не удалось: $restoreError. '
            'Не удалось автоматически вернуть прежнюю базу: '
            '$rollbackError. Страховочная копия сохранена: '
            '${safetyFile.path}',
          );
        }

        throw Exception(
          'Восстановление не удалось. Прежняя база возвращена. '
          'Причина: $restoreError',
        );
      }

      await _notify(
        type: NotificationType.success,
        eventType: 'backup_restored',
        title: LunoraLocalization.text('Данные восстановлены', 'Data restored'),
        message: '${LunoraLocalization.text('Резервная копия восстановлена: ')}${backup.fileName}',
        metadata: {
          'fileName': backup.fileName,
          'filePath': backup.filePath,
          'safetyCopy': safetyFile.path,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Ошибка восстановления базы данных: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _notify(
        type: NotificationType.error,
        eventType: 'backup_restore_failed',
        title: LunoraLocalization.text(
          'Ошибка восстановления',
          'Restore error',
        ),
        message: 'Не удалось восстановить резервную копию.',
        metadata: {'fileName': backup.fileName, 'error': error.toString()},
      );

      rethrow;
    } finally {
      try {
        if (temporaryFile != null && await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      } finally {
        try {
          if (databaseClosed) {
            await LunoraDatabase.instance.database;
          }
        } finally {
          _isRestoring = false;
        }
      }
    }
  }

  Future<void> _validateDatabase(String path) async {
    sqfliteFfiInit();

    Database? validationDatabase;

    try {
      validationDatabase = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true),
      );

      final result = await validationDatabase.rawQuery(
        'PRAGMA integrity_check',
      );

      final integrity = result.isEmpty
          ? null
          : result.first['integrity_check']?.toString().toLowerCase();

      if (integrity != 'ok') {
        throw Exception('Резервная копия повреждена или содержит ошибки.');
      }
    } finally {
      if (validationDatabase != null && validationDatabase.isOpen) {
        await validationDatabase.close();
      }
    }
  }

  Future<void> _deleteSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$databasePath$suffix');

      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _notify({
    required NotificationType type,
    required String eventType,
    required String title,
    required String message,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await NotificationService.instance.create(
        category: NotificationCategory.backups,
        type: type,
        eventType: eventType,
        title: title,
        message: message,
        sourceModule: 'backups',
        metadata: metadata,
      );
    } catch (error, stackTrace) {
      debugPrint('Ошибка уведомления о восстановлении: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _timestamp(DateTime date) {
    return '${date.year}'
        '${_twoDigits(date.month)}'
        '${_twoDigits(date.day)}_'
        '${_twoDigits(date.hour)}'
        '${_twoDigits(date.minute)}'
        '${_twoDigits(date.second)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
