import 'dart:io';

import 'package:flutter/material.dart';
import '../../books/repositories/book_repository.dart';
import '../../movies/repositories/movie_repository.dart';

import '../../../core/localization/lunora_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../models/collection_entry.dart';
import '../repositories/collection_repository.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final _repository = CollectionRepository.instance;
  List<CollectionEntry> _collections = [];
  CollectionEntry? _selected;
  List<CollectionItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selectId}) async {
    setState(() => _loading = true);
    try {
      final collections = await _repository.getAll();
      final selected = collections.where((e) => e.id == (selectId ?? _selected?.id)).firstOrNull;
      final items = selected == null ? <CollectionItem>[] : await _repository.getItems(selected.id);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _selected = selected;
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  Future<void> _createCollection() async {
    final result = await _showCollectionDialog();
    if (result == null) return;
    try {
      final entry = await _repository.create(
        name: result.$1, description: result.$2, colorValue: result.$3,
      );
      await _load(selectId: entry.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editCollection(CollectionEntry entry) async {
    final result = await _showCollectionDialog(entry: entry);
    if (result == null) return;
    try {
      await _repository.update(entry.copyWith(
        name: result.$1,
        description: result.$2,
        colorValue: result.$3,
        clearColorValue: result.$3 == null,
      ));
      await _load(selectId: entry.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<(String, String, int?)?> _showCollectionDialog({CollectionEntry? entry}) async {
    final name = TextEditingController(text: entry?.name ?? '');
    final description = TextEditingController(text: entry?.description ?? '');
    int? color = entry?.colorValue;
    const colors = [0xFF8FAF9A, 0xFFC99A9A, 0xFF9D91B8, 0xFFD0B477, 0xFF7F9EAF, 0xFFB58FAF];
    final result = await showDialog<(String, String, int?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text(
            entry == null ? 'Новая коллекция' : 'Редактировать коллекцию',
            entry == null ? 'New collection' : 'Edit collection',
          )),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true,
                decoration: InputDecoration(labelText: LunoraLocalization.text('Название', 'Name'))),
              const SizedBox(height: 12),
              TextField(controller: description, maxLines: 3,
                decoration: InputDecoration(labelText: LunoraLocalization.text('Описание', 'Description'))),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft,
                child: Text(LunoraLocalization.text('Цвет коллекции', 'Collection colour'))),
              const SizedBox(height: 10),
              Wrap(spacing: 10, children: [
                for (final value in colors)
                  InkWell(
                    onTap: () => setDialogState(() => color = value),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Color(value), shape: BoxShape.circle,
                        border: Border.all(
                          color: color == value ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => setDialogState(() => color = null),
                  child: Text(LunoraLocalization.text('Без цвета', 'No colour')),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Отмена', 'Cancel'))),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, (name.text.trim(), description.text.trim(), color));
              },
              child: Text(LunoraLocalization.text('Сохранить', 'Save')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    return result;
  }

  Future<void> _addRecord() async {
    final module = TextEditingController();
    final recordId = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Добавить запись', 'Add a record')),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: module, decoration: InputDecoration(
            labelText: LunoraLocalization.text('Раздел', 'Module'),
            hintText: 'books, movies, recipes, knowledge')),
          TextField(controller: recordId, decoration: InputDecoration(
            labelText: 'ID', hintText: LunoraLocalization.text('Идентификатор записи', 'Record identifier'))),
          TextField(controller: note, decoration: InputDecoration(
            labelText: LunoraLocalization.text('Заметка', 'Note'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: Text(LunoraLocalization.text('Отмена', 'Cancel'))),
          FilledButton(onPressed: () {
            if (module.text.trim().isEmpty || recordId.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, (module.text, recordId.text, note.text));
          }, child: Text(LunoraLocalization.text('Добавить', 'Add'))),
        ],
      ),
    );
    module.dispose(); recordId.dispose(); note.dispose();
    if (result == null || _selected == null) return;
    try {
      final added = await _repository.addRecord(
        collectionId: _selected!.id, recordModule: result.$1,
        recordId: result.$2, note: result.$3,
      );
      if (!added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(LunoraLocalization.text('Эта запись уже есть в коллекции.', 'This record is already in the collection.')),
        ));
      }
      await _load(selectId: _selected!.id);
    } catch (error) { _showError(error); }
  }

  Future<void> _deleteCollection(CollectionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить коллекцию?', 'Delete collection?')),
        content: Text(LunoraLocalization.text(
          'Коллекция «${entry.name}» и её список будут удалены. Исходные записи останутся.',
          '“${entry.name}” and its collection list will be deleted. Original records will remain.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(LunoraLocalization.text('Отмена', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(LunoraLocalization.text('Удалить', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(entry.id);
    await _load();
  }

  Future<void> _removeItem(CollectionItem item) async {
    await _repository.removeRecord(
      collectionId: item.collectionId, recordModule: item.recordModule, recordId: item.recordId,
    );
    await _load(selectId: item.collectionId);
  }

  Future<Map<String, String?>> _resolveRecord(CollectionItem item) async {
    switch (item.recordModule) {
      case 'books':
        final book = await BookRepository.instance.getById(item.recordId);
        return {
          'title': book?.title ?? LunoraLocalization.text('Книга недоступна', 'Book unavailable'),
          'subtitle': book?.authors ?? '',
          'image': book?.coverPath,
          'kind': 'book',
        };
      case 'movies':
        final movie = await MovieRepository.instance.getById(item.recordId);
        return {
          'title': movie?.title ?? LunoraLocalization.text('Фильм недоступен', 'Movie unavailable'),
          'subtitle': movie?.releaseYear?.toString() ?? '',
          'image': movie?.posterPath,
          'kind': 'movie',
        };
      default:
        return {
          'title': item.recordId,
          'subtitle': item.recordModule,
          'image': null,
          'kind': item.recordModule,
        };
    }
  }

  Widget _collectionItemTile(CollectionItem item, LunoraPalette palette) {
    return FutureBuilder<Map<String, String?>>(
      future: _resolveRecord(item),
      builder: (context, snapshot) {
        final record = snapshot.data;
        final path = record?['image'];
        final kind = record?['kind'];
        final icon = kind == 'book' ? Icons.menu_book_outlined
            : kind == 'movie' ? Icons.movie_outlined : _moduleIcon(item.recordModule);
        Widget cover = Container(
          width: 46, height: 62,
          decoration: BoxDecoration(
            color: palette.sagePanel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: palette.accent, size: 22),
        );
        if (path != null && path.isNotEmpty) {
          cover = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path), width: 46, height: 62, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => coverPlaceholder(icon, palette),
            ),
          );
        }
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
          leading: cover,
          title: Text(
            record?['title'] ?? LunoraLocalization.text('Загрузка…', 'Loading…'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [record?['subtitle'], if (item.note.isNotEmpty) item.note]
                .where((value) => value != null && value.isNotEmpty).join(' • '),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.secondary),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: LunoraLocalization.text('Убрать из коллекции', 'Remove from collection'),
            onPressed: () => _removeItem(item),
          ),
        );
      },
    );
  }

  Widget coverPlaceholder(IconData icon, LunoraPalette palette) => Container(
    width: 46, height: 62,
    decoration: BoxDecoration(color: palette.sagePanel, borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: palette.accent, size: 22),
  );

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(LunoraLocalization.text('Личные коллекции', 'Personal collections'),
                    style: TextStyle(color: palette.text, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(LunoraLocalization.text(
                    'Собирай книги, фильмы, идеи и всё, к чему хочется вернуться.',
                    'Gather books, films, ideas and everything you want to revisit.',
                  ), style: TextStyle(color: palette.secondary)),
                ])),
                FilledButton.icon(onPressed: _createCollection,
                  icon: const Icon(Icons.add), label: Text(LunoraLocalization.text('Создать', 'Create'))),
              ]),
              const SizedBox(height: 22),
              if (_loading) const Center(child: Padding(
                padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (_error != null) Center(child: Text(_error!))
              else if (_collections.isEmpty) _emptyState(palette)
              else if (compact) ...[
                _collectionGrid(palette, 1),
                if (_selected != null) ...[const SizedBox(height: 20), _detailPanel(palette)],
              ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _collectionGrid(palette, 2)),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: _selected == null
                  ? _selectHint(palette) : _detailPanel(palette)),
              ]),
            ]),
          ),
        ),
      );
    });
  }

  Widget _collectionGrid(LunoraPalette palette, int columns) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    itemCount: _collections.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12,
      mainAxisExtent: 142,
    ),
    itemBuilder: (context, index) {
      final entry = _collections[index];
      final selected = entry.id == _selected?.id;
      final tint = entry.colorValue == null ? palette.surface : Color(entry.colorValue!).withValues(alpha: .16);
      return Material(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _load(selectId: entry.id),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? palette.accent : palette.border, width: selected ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.collections_bookmark_outlined, color: entry.colorValue == null ? palette.accent : Color(entry.colorValue!)),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editCollection(entry);
                    if (value == 'delete') _deleteCollection(entry);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(LunoraLocalization.text('Изменить', 'Edit'))),
                    PopupMenuItem(value: 'delete', child: Text(LunoraLocalization.text('Удалить', 'Delete'))),
                  ],
                ),
              ]),
              const Spacer(),
              Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text('${entry.itemCount} ${LunoraLocalization.text('записей', 'items')}',
                style: TextStyle(color: palette.secondary, fontSize: 12)),
            ]),
          ),
        ),
      );
    },
  );

  Widget _detailPanel(LunoraPalette palette) {
    final entry = _selected!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(entry.name, style: TextStyle(color: palette.text, fontSize: 20, fontWeight: FontWeight.w700))),
          IconButton(onPressed: _addRecord, tooltip: LunoraLocalization.text('Добавить запись', 'Add record'),
            icon: Icon(Icons.add_circle_outline, color: palette.accent)),
        ]),
        if (entry.description.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(entry.description, style: TextStyle(color: palette.secondary))),
        const Divider(),
        if (_items.isEmpty) Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text(LunoraLocalization.text(
            'Здесь пока пусто. Добавь первую запись.',
            'Nothing here yet. Add the first record.',
          ), style: TextStyle(color: palette.secondary))),
        ) else ..._items.map((item) => _collectionItemTile(item, palette)),
      ]),
    );
  }

  Widget _emptyState(LunoraPalette palette) => Container(
    width: double.infinity, padding: const EdgeInsets.all(42),
    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: palette.border)),
    child: Column(children: [
      Icon(Icons.collections_bookmark_outlined, size: 42, color: palette.accent),
      const SizedBox(height: 14),
      Text(LunoraLocalization.text('Твои коллекции начинаются здесь', 'Your collections start here'),
        style: TextStyle(color: palette.text, fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 8),
      Text(LunoraLocalization.text('Создай подборку для книг, фильмов, рецептов или идей.',
        'Create a collection for books, films, recipes or ideas.'),
        textAlign: TextAlign.center, style: TextStyle(color: palette.secondary)),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _createCollection, icon: const Icon(Icons.add),
        label: Text(LunoraLocalization.text('Создать коллекцию', 'Create collection'))),
    ]),
  );

  Widget _selectHint(LunoraPalette palette) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: palette.border)),
    child: Center(child: Text(LunoraLocalization.text(
      'Выбери коллекцию, чтобы посмотреть её содержимое.',
      'Select a collection to view its contents.',
    ), textAlign: TextAlign.center, style: TextStyle(color: palette.secondary))),
  );

  IconData _moduleIcon(String module) => switch (module) {
    'books' => Icons.menu_book_outlined,
    'movies' => Icons.movie_outlined,
    'recipes' => Icons.restaurant_menu_outlined,
    'knowledge' => Icons.lightbulb_outline,
    _ => Icons.link_outlined,
  };
}
