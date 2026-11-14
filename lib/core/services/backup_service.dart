import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/storage/storage_service.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';
import 'package:lunora/shared/models/backup_info.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();
  static const Uuid _uuid = Uuid();

  bool _isCreatingBackup = false;

  Future<BackupInfo> createBackup() async {
    if (_isCreatingBackup) {
      throw Exception('Создание резервной копии уже выполняется.');
    }

    _isCreatingBackup = true;
    var databaseClosed = false;

    try {
      final database = await LunoraDatabase.instance.database;
      final databasePath = database.path;
      final sourceFile = File(databasePath);

      if (!await sourceFile.exists()) {
        throw Exception('Файл базы данных не найден.');
      }

      final checkpoint = await database.rawQuery(
        'PRAGMA wal_checkpoint(TRUNCATE)',
      );

      if (checkpoint.isEmpty || checkpoint.first['busy'] != 0) {
        throw Exception('Не удалось подготовить базу данных к копированию.');
      }

      await LunoraDatabase.instance.close();
      databaseClosed = true;

      final backupDirectory = await StorageService.instance.backupsDirectory;

      final now = DateTime.now();
      final suffix = _uuid.v4().substring(0, 8);
      final fileName = 'lunora_backup_${_timestamp(now)}_$suffix.db';
      final backupPath = p.join(backupDirectory.path, fileName);

      File? copiedFile;

      try {
        copiedFile = await sourceFile.copy(backupPath);

        if (!await copiedFile.exists() || await copiedFile.length() == 0) {
          throw Exception('Созданная резервная копия пуста.');
        }

        final backup = BackupInfo(
          id: _uuid.v4(),
          fileName: fileName,
          filePath: copiedFile.path,
          createdAt: now,
          fileSize: await copiedFile.length(),
          status: 'success',
        );

        await _notify(
          type: NotificationType.success,
          eventType: 'backup_created',
          title: LunoraLocalization.text(
            'Резервная копия создана',
            'Backup created',
          ),
          message: '${LunoraLocalization.text('Резервная копия сохранена: ')}$fileName',
          metadata: {
            'fileName': fileName,
            'filePath': copiedFile.path,
            'fileSize': backup.fileSize,
          },
        );

        return backup;
      } catch (_) {
        if (copiedFile != null && await copiedFile.exists()) {
          await copiedFile.delete();
        }
        rethrow;
      }
    } catch (error, stackTrace) {
      debugPrint('Ошибка создания резервной копии: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _notify(
        type: NotificationType.error,
        eventType: 'backup_failed',
        title: LunoraLocalization.text(
          'Ошибка резервного копирования',
          'Backup error',
        ),
        message: 'Не удалось создать резервную копию.',
        metadata: {'error': error.toString()},
      );

      rethrow;
    } finally {
      try {
        if (databaseClosed) {
          await LunoraDatabase.instance.database;
        }
      } finally {
        _isCreatingBackup = false;
      }
    }
  }

  Future<List<BackupInfo>> getBackups() async {
    final directory = await StorageService.instance.backupsDirectory;

    final entities = await directory.list().toList();
    final backups = <BackupInfo>[];

    for (final entity in entities) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.db') {
        continue;
      }

      final stat = await entity.stat();

      backups.add(
        BackupInfo(
          id: entity.path,
          fileName: p.basename(entity.path),
          filePath: entity.path,
          createdAt: stat.modified,
          fileSize: stat.size,
          status: 'success',
        ),
      );
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return backups;
  }

  Future<void> deleteBackup(BackupInfo backup) async {
    final directory = await StorageService.instance.backupsDirectory;

    final file = File(backup.filePath);

    final backupDirectoryPath = p.normalize(p.absolute(directory.path));
    final fileParent = p.normalize(p.absolute(p.dirname(file.path)));

    if (!p.equals(backupDirectoryPath, fileParent) ||
        p.extension(file.path).toLowerCase() != '.db') {
      throw Exception('Недопустимый путь к резервной копии.');
    }

    if (!await file.exists()) {
      throw Exception('Файл резервной копии уже не существует.');
    }

    await file.delete();
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
      debugPrint('Ошибка уведомления о резервной копии: $error');
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
