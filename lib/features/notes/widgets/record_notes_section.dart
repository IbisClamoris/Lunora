import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';
import '../models/record_note.dart';
import '../repositories/record_note_repository.dart';

class RecordNotesSection extends StatefulWidget {
  final String sourceModule;
  final String sourceRecordId;
  final String recordTitle;

  const RecordNotesSection({
    super.key,
    required this.sourceModule,
    required this.sourceRecordId,
    required this.recordTitle,
  });

  @override
  State<RecordNotesSection> createState() => _RecordNotesSectionState();
}

class _RecordNotesSectionState extends State<RecordNotesSection> {
  List<RecordNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await RecordNoteRepository.instance.getForRecord(
        widget.sourceModule,
        widget.sourceRecordId,
      );
      if (mounted) setState(() { _notes = notes; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([RecordNote? note]) async {
    final title = TextEditingController(text: note?.title ?? '');
    final content = TextEditingController(text: note?.content ?? '');
    final tags = TextEditingController(text: note?.tags.join(', ') ?? '');
    var pinned = note?.isPinned ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text(
            note == null ? 'Новая заметка' : 'Редактировать заметку',
            note == null ? 'New note' : 'Edit note',
          )),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Заголовок'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: content,
                    minLines: 4,
                    maxLines: 9,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Текст заметки'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Теги'),
                      hintText: LunoraLocalization.text('Через запятую'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pinned,
                    onChanged: (value) => setDialogState(() => pinned = value ?? false),
                    title: Text(LunoraLocalization.text('Закрепить заметку', 'Pin note')),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty && content.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final cleanTitle = title.text.trim().isEmpty
          ? LunoraLocalization.text('Заметка')
          : title.text.trim();
      final cleanTags = tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      try {
        if (note == null) {
          await RecordNoteRepository.instance.create(
            title: cleanTitle,
            content: content.text.trim(),
            sourceModule: widget.sourceModule,
            sourceRecordId: widget.sourceRecordId,
            tags: cleanTags,
            isPinned: pinned,
          );
        } else {
          await RecordNoteRepository.instance.update(RecordNote(
            id: note.id,
            title: cleanTitle,
            content: content.text.trim(),
            sourceModule: note.sourceModule,
            sourceRecordId: note.sourceRecordId,
            tags: cleanTags,
            isPinned: pinned,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
          ));
        }
        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LunoraLocalization.text('Не удалось сохранить заметку: $error', 'Could not save note: $error'))),
          );
        }
      }
    }

    title.dispose();
    content.dispose();
    tags.dispose();
  }

  Future<void> _delete(RecordNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить заметку?', 'Delete note?')),
        content: Text(LunoraLocalization.text('Это действие нельзя отменить.', 'This action cannot be undone.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(LunoraLocalization.text('Отмена'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(LunoraLocalization.text('Удалить'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await RecordNoteRepository.instance.delete(note);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: colors.primary, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                LunoraLocalization.text('Заметки', 'Notes'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(LunoraLocalization.text('Добавить')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_notes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              LunoraLocalization.text('Сохраняй здесь цитаты, мысли и впечатления об этом произведении.', 'Save quotes, thoughts and impressions about this title here.'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          )
        else
          ..._notes.map((note) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.isPinned) Icon(Icons.push_pin_rounded, size: 16, color: colors.primary),
                      if (note.isPinned) const SizedBox(width: 6),
                      Expanded(child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      IconButton(tooltip: LunoraLocalization.text('Редактировать'), onPressed: () => _edit(note), icon: const Icon(Icons.edit_outlined, size: 19)),
                      IconButton(tooltip: LunoraLocalization.text('Удалить'), onPressed: () => _delete(note), icon: const Icon(Icons.delete_outline, size: 19)),
                    ],
                  ),
                  if (note.content.isNotEmpty)
                    SelectableText(note.content, style: TextStyle(color: colors.onSurface, height: 1.5)),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 4, children: note.tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList()),
                  ],
                ],
              ),
            ),
          )),
      ],
    );
  }
}
