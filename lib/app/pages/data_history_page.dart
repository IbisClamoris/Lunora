import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/import_export/models/history_entry.dart';
import '../../core/import_export/services/history_service.dart';

class DataHistoryPage extends StatefulWidget {
  const DataHistoryPage({super.key});

  @override
  State<DataHistoryPage> createState() => _DataHistoryPageState();
}

class _DataHistoryPageState extends State<DataHistoryPage>
    with SingleTickerProviderStateMixin {
  static const double _contentMaxWidth = 1100;
  static const double _wideLayoutBreakpoint = 700;

  final HistoryService _service = HistoryService.instance;

  late final TabController _tabController;

  List<HistoryEntry> _imports = [];
  List<HistoryEntry> _exports = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closePage() {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getImportHistory(),
        _service.getExportHistory(),
      ]);

      if (!mounted) return;

      setState(() {
        _imports = results[0];
        _exports = results[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Дата неизвестна';
    }

    return DateFormat('dd.MM.yyyy · HH:mm').format(date);
  }

  Color _statusColor(HistoryEntry entry) {
    if (entry.isSuccessful) {
      return Colors.green;
    }

    return Theme.of(context).colorScheme.error;
  }

  String _statusText(HistoryEntry entry) {
    if (entry.isSuccessful) {
      return 'Успешно';
    }

    switch (entry.status.toLowerCase().trim()) {
      case 'failed':
      case 'error':
      case 'ошибка':
        return 'Ошибка';

      case 'pending':
      case 'processing':
        return 'В процессе';

      default:
        return entry.status;
    }
  }

  IconData _statusIcon(HistoryEntry entry) {
    if (entry.isSuccessful) {
      return Icons.check_circle_outline;
    }

    return Icons.error_outline;
  }

  Future<void> _showDetails(HistoryEntry entry) async {
    final isImport = entry.type == HistoryType.import;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Подробности операции')),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow('Файл', entry.fileName),
                  _detailRow('Тип операции', isImport ? 'Импорт' : 'Экспорт'),
                  _detailRow('Раздел', entry.sourceModule ?? 'Не указан'),
                  _detailRow('Дата', _formatDate(entry.date)),
                  if (isImport)
                    _detailRow(
                      'Импортировано записей',
                      '${entry.recordCount ?? 0}',
                    ),
                  _detailRow('Статус', _statusText(entry)),
                  const SizedBox(height: 12),
                  Text(
                    LunoraLocalization.text('Дополнительная информация'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    entry.details?.trim().isNotEmpty == true
                        ? entry.details!
                        : 'Дополнительная информация отсутствует.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Закрыть')),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(title, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isWide) {
    final importCard = _summaryCard(
      title: LunoraLocalization.text('Импортировано операций'),
      count: _imports.length,
      icon: Icons.file_download_outlined,
    );

    final exportCard = _summaryCard(
      title: LunoraLocalization.text('Экспортировано операций'),
      count: _exports.length,
      icon: Icons.file_upload_outlined,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: importCard),
          const SizedBox(width: 16),
          Expanded(child: exportCard),
        ],
      );
    }

    return Column(
      children: [importCard, const SizedBox(height: 10), exportCard],
    );
  }

  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: entries.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        final entry = entries[index];

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: _statusColor(entry).withValues(alpha: 0.12),
              child: Icon(_statusIcon(entry), color: _statusColor(entry)),
            ),
            title: Text(
              entry.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.sourceModule ?? 'Раздел не указан',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(_formatDate(entry.date)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(entry),
                            size: 15,
                            color: _statusColor(entry),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _statusText(entry),
                            style: TextStyle(
                              color: _statusColor(entry),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (entry.type == HistoryType.import)
                        Text(
                          LunoraLocalization.text(
                            '${entry.recordCount ?? 0} записей',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              tooltip: LunoraLocalization.text('Подробности'),
              onPressed: () => _showDetails(entry),
              icon: const Icon(Icons.info_outline),
            ),
            onTap: () => _showDetails(entry),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              LunoraLocalization.text('Пока здесь пусто'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              LunoraLocalization.text(
                'История операций появится после первого импорта или экспорта.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(
                LunoraLocalization.text(
                  'Не удалось загрузить историю операций.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: Text(LunoraLocalization.text('Повторить')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummary(isWide),
        const SizedBox(height: 20),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.file_download_outlined),
              text: LunoraLocalization.text('Импорт'),
            ),
            Tab(
              icon: const Icon(Icons.file_upload_outlined),
              text: LunoraLocalization.text('Экспорт'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryList(_imports),
              _buildHistoryList(_exports),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader(bool isCompact) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LunoraLocalization.text('История операций'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          LunoraLocalization.text('Журнал импорта и экспорта данных Lunora'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: LunoraLocalization.text('Обновить историю'),
          onPressed: _loading ? null : _loadHistory,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: LunoraLocalization.text('Закрыть'),
          onPressed: _closePage,
          icon: const Icon(Icons.close),
        ),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        actions,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _closePage},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
              final isCompact = constraints.maxWidth < 600;
              final horizontalPadding = isCompact ? 12.0 : 24.0;
              final verticalPadding = isCompact ? 16.0 : 24.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPageHeader(isCompact),
                        const SizedBox(height: 20),
                        Expanded(child: _buildContent(isWide)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
