import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/lunora_localization.dart';
import '../../books/models/book_entry.dart';
import '../../books/pages/book_details_page.dart';
import '../../books/repositories/book_repository.dart';
import '../../movies/models/movie_entry.dart';
import '../../movies/pages/movie_details_page.dart';
import '../../movies/repositories/movie_repository.dart';
import '../models/record_link.dart';
import '../repositories/record_link_repository.dart';

class _LinkCandidate {
  final String module;
  final String id;
  final String title;
  final String subtitle;
  const _LinkCandidate(this.module, this.id, this.title, this.subtitle);
}

class RecordLinksSection extends StatefulWidget {
  final String sourceModule;
  final String sourceRecordId;

  const RecordLinksSection({
    super.key,
    required this.sourceModule,
    required this.sourceRecordId,
  });

  @override
  State<RecordLinksSection> createState() => _RecordLinksSectionState();
}

class _RecordLinksSectionState extends State<RecordLinksSection> {
  List<LinkedRecord> _links = [];
  List<_LinkCandidate> _candidates = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        RecordLinkRepository.instance.getForRecord(widget.sourceModule, widget.sourceRecordId),
        _loadCandidates(),
      ]);
      if (!mounted) return;
      setState(() {
        _links = results[0] as List<LinkedRecord>;
        _candidates = results[1] as List<_LinkCandidate>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_LinkCandidate>> _loadCandidates() async {
    final books = await BookRepository.instance.getAll();
    final movies = await MovieRepository.instance.getAll();
    final db = await LunoraDatabase.instance.database;
    final notes = await db.query(
      'notes',
      where: 'source_record_id IS NOT NULL',
      orderBy: 'updated_at DESC',
    );
    final items = <_LinkCandidate>[
      ...books.map((BookEntry item) => _LinkCandidate('books', item.id, item.title,
        item.authors.isEmpty ? LunoraLocalization.text('Книга', 'Book') : item.authors)),
      ...movies.map((MovieEntry item) => _LinkCandidate('movies', item.id, item.title,
        item.releaseYear?.toString() ?? LunoraLocalization.text('Фильм или сериал', 'Movie or series'))),
      ...notes.map((row) => _LinkCandidate(
        'notes',
        row['id'] as String,
        row['title'] as String? ?? LunoraLocalization.text('Заметка', 'Note'),
        LunoraLocalization.text('Заметка', 'Note'),
      )),
    ];
    items.removeWhere((item) => item.module == widget.sourceModule && item.id == widget.sourceRecordId);
    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  Future<_LinkCandidate?> _resolve(LinkedRecord item) async {
    switch (item.module) {
      case 'books':
        final record = await BookRepository.instance.getById(item.recordId);
        if (record == null) return null;
        return _LinkCandidate('books', record.id, record.title,
          record.authors.isEmpty ? LunoraLocalization.text('Книга', 'Book') : record.authors);
      case 'movies':
        final record = await MovieRepository.instance.getById(item.recordId);
        if (record == null) return null;
        return _LinkCandidate('movies', record.id, record.title,
          record.releaseYear?.toString() ?? LunoraLocalization.text('Фильм или сериал', 'Movie or series'));
      case 'notes':
        final db = await LunoraDatabase.instance.database;
        final rows = await db.query('notes', where: 'id = ?', whereArgs: [item.recordId], limit: 1);
        if (rows.isEmpty) return null;
        final row = rows.first;
        return _LinkCandidate('notes', item.recordId,
          row['title'] as String? ?? LunoraLocalization.text('Заметка', 'Note'),
          LunoraLocalization.text('Заметка', 'Note'));
      default:
        return null;
    }
  }

  Future<void> _addLink() async {
    if (_candidates.isEmpty) {
      _message(LunoraLocalization.text('Пока нет других записей, которые можно связать.', 'There are no other records to link yet.'));
      return;
    }
    final existingKeys = _links.map((item) => '${item.module}:${item.recordId}').toSet();
    final available = _candidates.where((item) => !existingKeys.contains('${item.module}:${item.id}')).toList();
    if (available.isEmpty) {
      _message(LunoraLocalization.text('Все доступные записи уже связаны.', 'All available records are already linked.'));
      return;
    }

    final noteController = TextEditingController();
    final selected = await showDialog<_LinkCandidate>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Добавить связь', 'Add a link')),
        content: SizedBox(
          width: 520,
          height: 440,
          child: Column(
            children: [
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Комментарий (необязательно)', 'Note (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: available.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = available[index];
                    final icon = item.module == 'books'
                      ? Icons.menu_book_outlined
                      : item.module == 'movies'
                        ? Icons.movie_outlined
                        : Icons.sticky_note_2_outlined;
                    return ListTile(
                      leading: Icon(icon),
                      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.subtitle),
                      onTap: () => Navigator.pop(dialogContext, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LunoraLocalization.text('Отмена', 'Cancel')),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (selected == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await RecordLinkRepository.instance.create(
        sourceModule: widget.sourceModule,
        sourceRecordId: widget.sourceRecordId,
        targetModule: selected.module,
        targetRecordId: selected.id,
        note: note,
      );
      await _load();
    } catch (error) {
      _message(LunoraLocalization.text('Не удалось создать связь: $error', 'Could not create link: $error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(_LinkCandidate item) async {
    if (item.module == 'books') {
      final record = await BookRepository.instance.getById(item.id);
      if (record != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailsPage(book: record)));
      }
    } else if (item.module == 'movies') {
      final record = await MovieRepository.instance.getById(item.id);
      if (record != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieDetailsPage(movie: record)));
      } else if (item.module == 'notes') {
        await _openNoteSource(item.id);
      }
    } else if (item.module == 'notes') {
      await _openNoteSource(item.id);
    }
  }

  Future<void> _openNoteSource(String noteId) async {
    final db = await LunoraDatabase.instance.database;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [noteId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;
    final module = row['source_module'] as String? ?? '';
    final id = row['source_record_id'] as String? ?? '';
    if (module == 'books') {
      final record = await BookRepository.instance.getById(id);
      if (record != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailsPage(book: record)));
      }
    } else if (module == 'movies') {
      final record = await MovieRepository.instance.getById(id);
      if (record != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieDetailsPage(movie: record)));
      }
    }
  }

  Future<void> _remove(LinkedRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить связь?', 'Remove link?')),
        content: Text(LunoraLocalization.text('Сами записи и заметки останутся без изменений.', 'The records and notes themselves will not be changed.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(LunoraLocalization.text('Отмена', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(LunoraLocalization.text('Удалить', 'Remove'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await RecordLinkRepository.instance.delete(item.link.id);
    await _load();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub_outlined, color: colors.primary, size: 21),
            const SizedBox(width: 9),
            Expanded(child: Text(
              LunoraLocalization.text('Связанные записи', 'Related records'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            )),
            FilledButton.tonalIcon(
              onPressed: _loading || _saving ? null : _addLink,
              icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add, size: 18),
              label: Text(LunoraLocalization.text('Связать', 'Link')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_links.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              LunoraLocalization.text('Свяжи это произведение с экранизацией, заметкой или другой записью.', 'Link this title to an adaptation, note or another record.'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          )
        else
          ..._links.map((item) => FutureBuilder<_LinkCandidate?>(
            future: _resolve(item),
            builder: (context, snapshot) {
              final record = snapshot.data;
              if (record == null) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(title: LinearProgressIndicator());
                }
                return const SizedBox.shrink();
              }
              final icon = record.module == 'books'
                ? Icons.menu_book_outlined
                : record.module == 'movies'
                  ? Icons.movie_outlined
                  : Icons.sticky_note_2_outlined;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: colors.surfaceContainerLow,
                child: ListTile(
                  leading: Icon(icon, color: colors.primary),
                  title: Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.link.note.isEmpty ? record.subtitle : '${record.subtitle} · ${item.link.note}'),
                  onTap: () => _open(record),
                  trailing: IconButton(
                    tooltip: LunoraLocalization.text('Удалить связь', 'Remove link'),
                    onPressed: () => _remove(item),
                    icon: const Icon(Icons.link_off_outlined),
                  ),
                ),
              );
            },
          )),
      ],
    );
  }
}
