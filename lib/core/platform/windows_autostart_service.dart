import 'dart:io';

import 'package:flutter/foundation.dart';

/// Registers Lunora in the current Windows user's Run registry key.
class WindowsAutostartService {
  WindowsAutostartService._();

  static final WindowsAutostartService instance = WindowsAutostartService._();

  static const String _registryKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _valueName = 'Lunora';

  bool get isSupported => !kIsWeb && Platform.isWindows;

  Future<bool> isEnabled() async {
    if (!isSupported) return false;

    final result = await Process.run('reg.exe', [
      'query',
      _registryKey,
      '/v',
      _valueName,
    ], runInShell: false);
    return result.exitCode == 0;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) {
      throw UnsupportedError('Автозапуск поддерживается только в Windows.');
    }

    if (enabled) {
      final executable = Platform.resolvedExecutable;
      if (executable.isEmpty || !File(executable).existsSync()) {
        throw StateError('Не удалось определить исполняемый файл Lunora.');
      }

      final command = '"${File(executable).absolute.path}"';
      final result = await Process.run('reg.exe', [
        'add',
        _registryKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ], runInShell: false);

      if (result.exitCode != 0) {
        throw ProcessException(
          'reg.exe',
          ['add', _registryKey, '/v', _valueName],
          '${result.stderr}\n${result.stdout}',
          result.exitCode,
        );
      }
    } else {
      await Process.run('reg.exe', [
        'delete',
        _registryKey,
        '/v',
        _valueName,
        '/f',
      ], runInShell: false);

      // `reg.exe delete` returns a non-zero exit code when the value is
      // already absent. Its message is localized by Windows, so do not parse
      // stderr/stdout: verify the desired state below instead. If deletion
      // failed for a real reason (for example, access denied), the value will
      // still be present and the final state check will report the failure.
    }

    final actualState = await isEnabled();
    if (actualState != enabled) {
      throw StateError(
        'Не удалось ${enabled ? 'включить' : 'отключить'} автозапуск Lunora.',
      );
    }
  }
}
