import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  Directory? _rootDirectory;

  Future<Directory> get rootDirectory async {
    if (_rootDirectory != null && await _rootDirectory!.exists()) {
      return _rootDirectory!;
    }

    final appDirectory = await getApplicationSupportDirectory();
    final root = Directory(p.join(appDirectory.path, 'Lunora'));

    // The Windows publisher name is changing from "Maria Brazhe" to
    // "Lunora". Keep the old user data available by copying it to the new
    // location before any database or storage directory is created.
    await _migrateLegacyWindowsRoot(root);

    await root.create(recursive: true);
    _rootDirectory = root;
    return root;
  }

  Future<void> _migrateLegacyWindowsRoot(Directory newRoot) async {
    if (!Platform.isWindows) return;

    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return;

    final legacyRoot = Directory(
      p.join(appData, 'Maria Brazhe', 'lunora', 'Lunora'),
    );
    if (!await legacyRoot.exists()) return;

    // Never replace existing files in the new location. This makes startup
    // migration safe to retry and leaves the entire legacy folder untouched.
    await _copyMissingFiles(legacyRoot, newRoot);
  }

  Future<void> _copyMissingFiles(Directory source, Directory destination) async {
    await destination.create(recursive: true);

    await for (final entity in source.list(followLinks: false)) {
      final targetPath = p.join(destination.path, p.basename(entity.path));

      if (entity is Directory) {
        await _copyMissingFiles(entity, Directory(targetPath));
      } else if (entity is File) {
        final target = File(targetPath);
        if (!await target.exists()) {
          await target.parent.create(recursive: true);
          await entity.copy(target.path);
        }
      }
    }
  }

  Future<Directory> get dataDirectory async {
    return _createDirectory('Data');
  }

  Future<Directory> get attachmentsDirectory async {
    return _createDirectory('Data/Attachments');
  }

  Future<Directory> get coversDirectory async {
    return _createDirectory('Data/Covers');
  }

  Future<Directory> get exportsDirectory async {
    return _createDirectory('Data/Exports');
  }

  Future<Directory> get backupsDirectory async {
    return _createDirectory('Backups');
  }

  Future<Directory> get themesDirectory async {
    return _createDirectory('Themes');
  }

  Future<Directory> get logsDirectory async {
    return _createDirectory('Logs');
  }

  Future<Directory> _createDirectory(String relativePath) async {
    final root = await rootDirectory;
    final directory = Directory(p.join(root.path, relativePath));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> createFile({
    required String relativePath,
    required String fileName,
  }) async {
    final root = await rootDirectory;
    final file = File(p.join(root.path, relativePath, fileName));
    await file.parent.create(recursive: true);
    return file;
  }

  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}
