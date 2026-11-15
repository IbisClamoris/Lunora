import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/knowledge_entry.dart';
import '../repositories/knowledge_repository.dart';
import 'knowledge_editor_page.dart';

class KnowledgeDetailPage extends StatefulWidget {
  final String entryId;

  const KnowledgeDetailPage({super.key, required this.entryId});

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage> {
  final KnowledgeRepository _repository = KnowledgeRepository.instance;

  KnowledgeEntry? _entry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    try {
      final entry = await _repository.getById(widget.entryId);

      if (!mounted) return;

      setState(() {
        _entry = entry;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить запись: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final entry = _entry;
    if (entry == null) return;

    try {
      await _repository.toggleFavorite(entry.id, isFavorite: !entry.isFavorite);

      await _loadEntry();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось изменить избранное: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _editEntry() async {
    final entry = _entry;
    if (entry == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeEditorPage(entry: entry),
      ),
    );

    if (!mounted) return;
    await _loadEntry();
  }

  Future<void> _deleteEntry() async {
    final entry = _entry;
    if (entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = Theme.of(dialogContext).extension<LunoraPalette>()!;

        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            LunoraLocalization.text('Удалить запись?'),
            style: TextStyle(color: palette.text),
          ),
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Запись «${entry.title}» будет удалена без возможности восстановления.', 'Entry “${entry.title}” will be permanently deleted.'),
            ),
            style: TextStyle(color: palette.secondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Удалить')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.delete(entry.id);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось удалить запись: $e'),
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Widget _buildMetadata(LunoraPalette palette, KnowledgeEntry entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metadataChip(palette, Icons.folder_outlined, entry.category),
        _metadataChip(
          palette,
          Icons.calendar_today_outlined,
          LunoraLocalization.text('Добавлено ${_formatDate(entry.createdAt)}', 'Added ${_formatDate(entry.createdAt)}'),
        ),
        _metadataChip(
          palette,
          Icons.update_outlined,
          LunoraLocalization.text('Обновлено ${_formatDate(entry.updatedAt)}', 'Updated ${_formatDate(entry.updatedAt)}'),
        ),
      ],
    );
  }

  Widget _metadataChip(LunoraPalette palette, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.sagePanel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.text),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: palette.text, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildContent(LunoraPalette palette, KnowledgeEntry entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: SelectableText(
        entry.content.trim().isEmpty
            ? LunoraLocalization.text('Содержимое записи пока не добавлено.', 'No content has been added to this entry yet.')
            : entry.content,
        style: TextStyle(
          color: entry.content.trim().isEmpty
              ? palette.secondary
              : palette.text,
          fontSize: 14,
          height: 1.8,
        ),
      ),
    );
  }

  Widget _buildTags(LunoraPalette palette, KnowledgeEntry entry) {
    if (entry.tags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LunoraLocalization.text('Теги'),
          style: TextStyle(
            color: palette.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entry.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: palette.lavender,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(color: palette.text, fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSource(LunoraPalette palette, String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              sourceUrl,
              style: TextStyle(color: palette.accent, fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Открыть ссылку'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LunoraLocalization.text(
                      LunoraLocalization.text('Открытие ссылок будет добавлено на следующем этапе.', 'Opening links will be added in a future update.'),
                    ),
                  ),
                ),
              );
            },
            icon: Icon(Icons.open_in_new, color: palette.secondary, size: 19),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
        title: Text(LunoraLocalization.text('Запись')),
        actions: [
          if (_entry != null) ...[
            IconButton(
              tooltip: _entry!.isFavorite
                  ? LunoraLocalization.text('Убрать из избранного', 'Remove from favourites')
                  : LunoraLocalization.text('В избранное', 'Add to favourites'),
              onPressed: _toggleFavorite,
              icon: Icon(
                _entry!.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _entry!.isFavorite ? palette.accent : palette.secondary,
              ),
            ),
            IconButton(
              tooltip: LunoraLocalization.text('Редактировать'),
              onPressed: _editEntry,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteEntry();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(LunoraLocalization.text('Удалить запись')),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entry == null
          ? Center(
              child: Text(
                LunoraLocalization.text('Запись не найдена'),
                style: TextStyle(color: palette.secondary),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 16 : 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _entry!.title,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: compact ? 23 : 29,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildMetadata(palette, _entry!),
                          const SizedBox(height: 24),
                          _buildContent(palette, _entry!),
                          const SizedBox(height: 24),
                          _buildTags(palette, _entry!),
                          if (_entry!.tags.isNotEmpty)
                            const SizedBox(height: 24),
                          _buildSource(palette, _entry!.sourceUrl),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
