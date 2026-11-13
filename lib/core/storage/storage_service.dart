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

    _rootDirectory = Directory(p.join(appDirectory.path, 'Lunora'));

    await _rootDirectory!.create(recursive: true);

    return _rootDirectory!;
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

    if (!await file.exists()) {
      return false;
    }

    await file.delete();

    return true;
  }
}
