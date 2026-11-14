import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/backup_service.dart';

const String lunoraAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.1',
);

class LunoraUpdate {
  const LunoraUpdate({
    required this.version,
    required this.notes,
    required this.installerUrl,
    required this.checksumUrl,
  });

  final String version;
  final String notes;
  final String installerUrl;
  final String checksumUrl;
}

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();
  static const _releaseApi =
      'https://api.github.com/repos/IbisClamoris/Lunora/releases/latest';

  Future<LunoraUpdate?> checkForUpdate() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(_releaseApi));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Lunora-Updater');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub returned HTTP ${response.statusCode}');
      }

      final payload = jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
      final tag = (payload['tag_name'] as String?) ?? '';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (version.isEmpty || !_isNewer(version, lunoraAppVersion)) return null;

      final assets = (payload['assets'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final installer = assets.firstWhere(
        (asset) => ((asset['name'] as String?) ?? '').endsWith('.exe'),
        orElse: () => <String, dynamic>{},
      );
      final checksum = assets.firstWhere(
        (asset) => ((asset['name'] as String?) ?? '').endsWith('.exe.sha256'),
        orElse: () => <String, dynamic>{},
      );
      final installerUrl = installer['browser_download_url'] as String?;
      final checksumUrl = checksum['browser_download_url'] as String?;
      if (installerUrl == null || checksumUrl == null) {
        throw const FormatException(
          'The release does not contain an installer and SHA-256 file.',
        );
      }

      return LunoraUpdate(
        version: version,
        notes: (payload['body'] as String?) ?? '',
        installerUrl: installerUrl,
        checksumUrl: checksumUrl,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> downloadVerifyBackupAndInstall(LunoraUpdate update) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Lunora updates are currently available on Windows only.');
    }

    final directory = await getTemporaryDirectory();
    final installer = File(p.join(directory.path, 'Lunora-Setup-${update.version}.exe'));
    final checksumFile = File('${installer.path}.sha256');

    await _download(update.installerUrl, installer);
    await _download(update.checksumUrl, checksumFile);

    final expected = (await checksumFile.readAsString()).trim().split(RegExp(r'\\s+')).first.toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
      throw const FormatException('The release checksum file is invalid.');
    }

    final actual = await sha256.bind(installer.openRead()).first;
    if (actual.toString() != expected) {
      await installer.delete();
      await checksumFile.delete();
      throw const FormatException('SHA-256 verification failed. The installer was not started.');
    }

    // A verified installer is not allowed to replace the application before a
    // database backup has been completed successfully.
    await BackupService.instance.createBackup();

    await Process.start(
      installer.path,
      const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ],
      mode: ProcessStartMode.detached,
    );

    // Inno Setup closes the running application before replacing its files.
    exit(0);
  }

  Future<void> _download(String url, File destination) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'Lunora-Updater')
        ..set(HttpHeaders.acceptHeader, 'application/octet-stream');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with HTTP ${response.statusCode}');
      }
      final sink = destination.openWrite();
      try {
        await response.pipe(sink);
      } catch (_) {
        await sink.close();
        if (await destination.exists()) await destination.delete();
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  bool _isNewer(String candidate, String current) {
    final next = _versionParts(candidate);
    final installed = _versionParts(current);
    for (var i = 0; i < 3; i++) {
      if (next[i] != installed[i]) return next[i] > installed[i];
    }
    return false;
  }

  List<int> _versionParts(String value) {
    final parts = value.split('.').take(3).toList();
    if (parts.length != 3 || parts.any((part) => int.tryParse(part) == null)) {
      throw FormatException('Invalid application version: $value');
    }
    return parts.map(int.parse).toList();
  }
}
