import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';

import '../services/movie_metadata_service.dart';

class MovieWebSearchPage extends StatefulWidget {
  const MovieWebSearchPage({super.key});

  @override
  State<MovieWebSearchPage> createState() => _MovieWebSearchPageState();
}

class _MovieWebSearchPageState extends State<MovieWebSearchPage> {
  final _queryController = TextEditingController();
  String _searchMode = 'title';
  List<MovieMetadata> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = _searchMode == 'person'
          ? await MovieMetadataService.instance.searchByPerson(query)
          : await MovieMetadataService.instance.searchSeries(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _error = _searchMode == 'person'
              ? 'По этому актёру или режиссёру сериалы не найдены.'
              : 'Фильмы, сериалы или аниме не найдены. Попробуй другое название.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Ошибка поиска: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Поиск фильмов и сериалов')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'title',
                      label: Text(LunoraLocalization.text('По названию')),
                      icon: Icon(Icons.movie_outlined),
                    ),
                    ButtonSegment(
                      value: 'person',
                      label: Text(LunoraLocalization.text('По человеку')),
                      icon: Icon(Icons.person_search_outlined),
                    ),
                  ],
                  selected: {_searchMode},
                  onSelectionChanged: (value) =>
                      setState(() => _searchMode = value.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: _searchMode == 'person'
                              ? 'Имя актёра или режиссёра'
                              : 'Название фильма, сериала или аниме',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _loading ? null : _search,
                      child: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    LunoraLocalization.text(
                      'Подключены открытые каталоги TVmaze, AniList и Wikidata. Регистрация и API-ключ не нужны.',
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
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
                        'Введи название фильма, сериала, аниме или имя актёра',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final details = [
                        if (item.releaseYear != null)
                          item.releaseYear.toString(),
                        if (item.runtimeMinutes != null)
                          '${item.runtimeMinutes} мин.',
                        if (item.genres.isNotEmpty) item.genres.join(', '),
                      ].join(' • ');
                      return Card(
                        child: ListTile(
                          leading: item.posterUrl == null
                              ? const SizedBox(
                                  width: 54,
                                  child: Icon(Icons.movie_outlined, size: 32),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.posterUrl!,
                                    width: 54,
                                    height: 78,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 54,
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              details,
                              item.description,
                            ].where((s) => s.isNotEmpty).join('\n'),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).pop(item),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(LunoraLocalization.text('Добавить')),
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
