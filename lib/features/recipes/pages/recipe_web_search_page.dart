import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';

import '../services/recipe_metadata_service.dart';
import 'recipe_editor_page.dart';

class RecipeWebSearchPage extends StatefulWidget {
  const RecipeWebSearchPage({super.key});

  @override
  State<RecipeWebSearchPage> createState() => _RecipeWebSearchPageState();
}

class _RecipeWebSearchPageState extends State<RecipeWebSearchPage> {
  final _controller = TextEditingController();
  final _service = RecipeMetadataService.instance;
  List<RecipeSearchResult> _results = [];
  bool _loading = false;
  String? _error;
  String? _importingUrl;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'Источники не вернули результаты. Попробуй другое название или проверь подключение к интернету.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось выполнить поиск: $error';
      });
    }
  }

  Future<void> _import(RecipeSearchResult result) async {
    if (_importingUrl != null) return;
    setState(() => _importingUrl = result.url);
    try {
      final data = await _service.importRecipe(result);
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => RecipeEditorPage(importData: data)),
      );
      if (!mounted) return;
      if (saved == true) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить рецепт: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importingUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Поиск рецептов', 'Recipe search')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: LunoraLocalization.text(
                  'Ищи блюдо по названию или ингредиентам',
                ),
                hintText: LunoraLocalization.text(
                  'Например, борщ или курица с картошкой',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                  tooltip: LunoraLocalization.text('Искать'),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                LunoraLocalization.text(
                  'Источники: 1000.menu · povarenok.ru · eda.ru · gastronom.ru · say7.info',
                  'Sources: 1000.menu · povarenok.ru · eda.ru · gastronom.ru · say7.info',
                ),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? 'Введи название блюда или ингредиент и нажми поиск.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final importing = _importingUrl == result.url;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: result.imageUrl == null
                                    ? Container(
                                        width: 76,
                                        height: 76,
                                        color: colors.surfaceContainerHighest,
                                        child: const Icon(Icons.restaurant),
                                      )
                                    : Image.network(
                                        result.imageUrl!,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 76,
                                          height: 76,
                                          color: colors.surfaceContainerHighest,
                                          child: const Icon(Icons.restaurant),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (result.snippet.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        result.snippet,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 5),
                                    Text(
                                      result.sourceName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: _importingUrl == null
                                    ? () => _import(result)
                                    : null,
                                icon: importing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: Text(
                                  importing ? 'Загрузка' : 'Добавить',
                                ),
                              ),
                            ],
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
