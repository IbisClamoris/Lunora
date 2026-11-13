import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/restore_service.dart';
import '../../shared/models/backup_info.dart';

class BackupManagementPage extends StatefulWidget {
  const BackupManagementPage({super.key});

  @override
  State<BackupManagementPage> createState() => _BackupManagementPageState();
}

class _BackupManagementPageState extends State<BackupManagementPage> {
  static const double _contentMaxWidth = 900;
  static const double _compactBreakpoint = 600;

  final BackupService _backupService = BackupService.instance;
  final RestoreService _restoreService = RestoreService.instance;

  List<BackupInfo> _backups = [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _loading = true;
    });

    try {
      final backups = await _backupService.getBackups();

      if (mounted) {
        setState(() {
          _backups = backups;
        });
      }
    } catch (error) {
      _showMessage('Не удалось загрузить копии: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _working = true;
    });

    try {
      final backup = await _backupService.createBackup();
      await _loadBackups();

      if (mounted) {
        _showMessage('Резервная копия создана: ${backup.fileName}');
      }
    } catch (error) {
      _showMessage('Ошибка создания копии: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Восстановить базу данных?')),
        content: Text(
          LunoraLocalization.isEnglish
              ? 'Lunora will replace the current database with the file "${backup.fileName}".\n\nA safety backup of the current database will be created first. Data added after the selected backup may be lost.'
              : 'Lunora заменит текущую базу данными из файла "${backup.fileName}".\n\nПеред заменой будет создана страховочная копия текущей базы. Текущие данные, появившиеся после выбранной резервной копии, могут быть потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Восстановить')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
    });

    try {
      await _restoreService.restoreBackup(backup);

      if (mounted) {
        _showMessage('База данных успешно восстановлена.');
        await _loadBackups();
      }
    } catch (error) {
      _showMessage('Ошибка восстановления: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить резервную копию?')),
        content: Text(
          LunoraLocalization.isEnglish
              ? 'The file "${backup.fileName}ill be permanently deleted.'
              : 'Файл "${backup.fileName}" будет удалён без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Удалить')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
    });

    try {
      await _backupService.deleteBackup(backup);
      await _loadBackups();

      if (mounted) {
        _showMessage('Резервная копия удалена.');
      }
    } catch (error) {
      _showMessage('Не удалось удалить копию: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
  }

  Widget _buildBackupCard(BackupInfo backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.storage_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backup.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _formatDate(backup.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatSize(backup.fileSize),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _working ? null : () => _restoreBackup(backup),
                  icon: const Icon(Icons.restore),
                  label: Text(LunoraLocalization.text('Восстановить')),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _deleteBackup(backup),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(LunoraLocalization.text('Удалить')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(LunoraLocalization.text('Резервных копий пока нет')),
              const SizedBox(height: 6),
              Text(
                LunoraLocalization.text(
                  'Создай первую копию, чтобы защитить свои данные.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent({required bool compact}) {
    final horizontalPadding = compact ? 16.0 : 28.0;
    final verticalPadding = compact ? 20.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LunoraLocalization.text('Защита данных Lunora'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${LunoraLocalization.text('Создавай резервные копии и восстанавливай ')}данные приложения при необходимости.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _working ? null : _createBackup,
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(
                    LunoraLocalization.text('Создать резервную копию'),
                  ),
                ),
              ),
              SizedBox(height: compact ? 24 : 32),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    LunoraLocalization.text('Сохранённые копии'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    LunoraLocalization.text('Всего: ${_backups.length}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_backups.isEmpty)
                _buildEmptyState()
              else
                ..._backups.map(_buildBackupCard),
              const SizedBox(height: 24),
              Text(
                '${LunoraLocalization.text('Перед восстановлением Lunora автоматически ')}сохраняет текущую базу в отдельную страховочную копию.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Резервные копии')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Обновить список'),
            onPressed: _working ? null : _loadBackups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactBreakpoint;

          return Stack(
            children: [
              _buildContent(compact: compact),
              if (_working)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}
