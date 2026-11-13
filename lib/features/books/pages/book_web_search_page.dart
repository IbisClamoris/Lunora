import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/search/web_search_controller.dart';
import '../models/book_entry.dart';
import '../repositories/book_repository.dart';
import '../services/book_metadata_service.dart';

class BookWebSearchPage extends StatefulWidget {
  const BookWebSearchPage({super.key});

  @override
  State<BookWebSearchPage> createState() => _BookWebSearchPageState();
}

class _BookWebSearchPageState extends State<BookWebSearchPage> {
  final _queryController = TextEditingController();
  final _search = WebSearchController();
  final _uuid = const Uuid();
  List<WebSearchHit> _results = [];
  bool _loading = false;
  String? _error;
  final Set<String> _added = {};
  final Set<String> _adding = {};

  @override
  void dispose() {
    _queryController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await _search.searchBooks(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _error = 'Не удалось извлечь результаты. Возможно, Яндекс показал проверку или изменил разметку.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Ошибка поиска: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBook(WebSearchHit hit) async {
    final now = DateTime.now();
    final fallbackTitle = hit.title.trim();
    if (mounted) setState(() => _adding.add(hit.url));

    try {
      // Сначала пытаемся получить структурированные данные каталога.
      // Если Open Library не знает книгу, сохраняем чистые данные из поиска.
      final metadata = await BookMetadataService.instance.lookup(
        title: fallbackTitle,
        author: hit.author,
      );

      final title = metadata?.title.isNotEmpty == true
          ? metadata!.title
          : fallbackTitle;
      final author = metadata?.author.isNotEmpty == true
          ? metadata!.author
          : hit.author;
      final description = metadata?.description.isNotEmpty == true
          ? metadata!.description
          : hit.description;

      await BookRepository.instance.create(
        BookEntry(
          id: _uuid.v4(),
          title: title,
          authors: author,
          description: description,
          coverPath: metadata?.coverPath,
          pageCount: metadata?.pageCount,
          genre: metadata?.genre ?? '',
          seriesName: metadata?.seriesName ?? '',
          seriesNumber: metadata?.seriesNumber,
          sourceName:
              metadata?.sourceName ?? (Uri.tryParse(hit.url)?.host ?? 'Яндекс'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (!mounted) return;
      setState(() => _added.add(hit.url));
      final enriched = metadata != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enriched
                ? '«$title» добавлена. Данные каталога и обложка загружены.'
                : '«$title» добавлена. Дополнительные данные в каталоге не найдены.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось добавить книгу: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding.remove(hit.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Поиск книг в интернете')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: LunoraLocalization.text(
                        'Название книги или автор',
                      ),
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loading ? null : _runSearch,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      LunoraLocalization.text(
                        'Введи название книги или автора',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final hit = _results[index];
                      final added = _added.contains(hit.url);
                      final adding = _adding.contains(hit.url);
                      return Card(
                        child: ListTile(
                          title: Text(
                            hit.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (hit.author.isNotEmpty) hit.author,
                              if (hit.description.isNotEmpty) hit.description,
                            ].join('\n'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: added
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : adding
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  tooltip: LunoraLocalization.text(
                                    'Добавить в библиотеку',
                                  ),
                                  onPressed: adding
                                      ? null
                                      : () => _addBook(hit),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
