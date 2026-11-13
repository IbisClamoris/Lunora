import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../models/knowledge_entry.dart';
import '../repositories/knowledge_repository.dart';
import 'knowledge_detail_page.dart';
import 'knowledge_editor_page.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  final KnowledgeRepository _repository = KnowledgeRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<KnowledgeEntry> _entries = [];

  String? _selectedCategory;
  String _sortBy = 'updated_at';
  bool _descending = true;
  bool _favoritesOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final entries = await _repository.getAll(
        searchQuery: _searchController.text,
        category: _selectedCategory,
        favoritesOnly: _favoritesOnly,
        sortBy: _sortBy,
        descending: _descending,
      );

      if (!mounted) return;

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить записи: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _openEditor([KnowledgeEntry? entry]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeEditorPage(entry: entry),
      ),
    );

    if (!mounted) return;
    await _loadEntries();
  }

  Future<void> _openDetails(KnowledgeEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeDetailPage(entryId: entry.id),
      ),
    );

    if (!mounted) return;
    await _loadEntries();
  }

  Future<void> _toggleFavorite(KnowledgeEntry entry) async {
    try {
      await _repository.toggleFavorite(entry.id, isFavorite: !entry.isFavorite);

      await _loadEntries();
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

  Future<void> _deleteEntry(KnowledgeEntry entry) async {
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
            LunoraLocalization.text('Запись «${entry.title}» будет удалена.'),
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
      await _loadEntries();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Запись удалена'))),
      );
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

  void _changeCategory(String? category) {
    setState(() => _selectedCategory = category);
    _loadEntries();
  }

  void _changeSort(String? value) {
    if (value == null) return;

    setState(() => _sortBy = value);
    _loadEntries();
  }

  Widget _buildSearchField(LunoraPalette palette) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _loadEntries(),
      style: TextStyle(color: palette.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: LunoraLocalization.text(
          'Поиск по названию, содержимому и тегам',
        ),
        hintStyle: TextStyle(color: palette.secondary),
        prefixIcon: Icon(Icons.search, color: palette.secondary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  _loadEntries();
                },
                icon: Icon(Icons.close, color: palette.secondary),
              )
            : null,
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(LunoraPalette palette) {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: LunoraLocalization.text('Категория'),
        labelStyle: TextStyle(color: palette.secondary),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
      dropdownColor: palette.surface,
      style: TextStyle(color: palette.text),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(LunoraLocalization.text('Все категории')),
        ),
        ...KnowledgeEntry.categories.map(
          (category) =>
              DropdownMenuItem<String?>(value: category, child: Text(category)),
        ),
      ],
      onChanged: _changeCategory,
    );
  }

  Widget _buildSortMenu(LunoraPalette palette) {
    return DropdownButton<String>(
      value: _sortBy,
      dropdownColor: palette.surface,
      underline: const SizedBox.shrink(),
      style: TextStyle(color: palette.text, fontSize: 13),
      items: [
        DropdownMenuItem(
          value: 'updated_at',
          child: Text(LunoraLocalization.text('По обновлению')),
        ),
        DropdownMenuItem(
          value: 'created_at',
          child: Text(LunoraLocalization.text('По добавлению')),
        ),
        DropdownMenuItem(
          value: 'title',
          child: Text(LunoraLocalization.text('По названию')),
        ),
        DropdownMenuItem(
          value: 'category',
          child: Text(LunoraLocalization.text('По категории')),
        ),
      ],
      onChanged: _changeSort,
    );
  }

  Widget _buildEntryCard(KnowledgeEntry entry, LunoraPalette palette) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(entry),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.category,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: entry.isFavorite
                        ? 'Убрать из избранного'
                        : 'В избранное',
                    onPressed: () => _toggleFavorite(entry),
                    icon: Icon(
                      entry.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: entry.isFavorite
                          ? palette.accent
                          : palette.secondary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: palette.secondary),
                    color: palette.surface,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openEditor(entry);
                      } else if (value == 'delete') {
                        _deleteEntry(entry);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(LunoraLocalization.text('Редактировать')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(LunoraLocalization.text('Удалить')),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.content.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags.take(5).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.sagePanel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(color: palette.text, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: palette.secondary),
                  const SizedBox(width: 5),
                  Text(
                    _formatDate(entry.updatedAt),
                    style: TextStyle(color: palette.secondary, fontSize: 11),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: palette.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LunoraPalette palette) {
    final hasFilters =
        _searchController.text.isNotEmpty ||
        _selectedCategory != null ||
        _favoritesOnly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.auto_stories_outlined,
            size: 42,
            color: palette.accent,
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters ? 'Ничего не найдено' : 'Твоя библиотека пока пуста',
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'Попробуй изменить поисковый запрос или фильтры.'
                : 'Добавляй материалы, конспекты, идеи и всё, '
                      'что захочется сохранить.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.secondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCategory = null;
                  _favoritesOnly = false;
                });
                _loadEntries();
              },
              child: Text(LunoraLocalization.text('Сбросить фильтры')),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Widget _buildHeader(LunoraPalette palette, bool compact) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18, 16, 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 46 : 54,
            height: compact ? 46 : 54,
            decoration: BoxDecoration(
              color: palette.sagePanel,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: palette.text,
              size: compact ? 24 : 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LunoraLocalization.text('МОЁ ПРОСТРАНСТВО'),
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LunoraLocalization.text('Библиотека знаний'),
                  style: TextStyle(
                    color: palette.text,
                    fontSize: compact ? 20 : 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  LunoraLocalization.text(
                    'Материалы, заметки и идеи, которые хочется сохранить.',
                  ),
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!compact)
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(LunoraLocalization.text('Добавить')),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
              ),
            )
          else
            IconButton.filled(
              tooltip: LunoraLocalization.text('Добавить запись'),
              onPressed: () => _openEditor(),
              style: IconButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(LunoraPalette palette, bool compact) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSearchField(palette)),
            const SizedBox(width: 10),
            SizedBox(
              width: compact ? 145 : 210,
              child: _buildCategoryFilter(palette),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilterChip(
              selected: _favoritesOnly,
              label: Text(LunoraLocalization.text('Избранное')),
              avatar: const Icon(Icons.star_outline_rounded, size: 17),
              onSelected: (value) {
                setState(() => _favoritesOnly = value);
                _loadEntries();
              },
              selectedColor: palette.lavender,
            ),
            const Spacer(),
            Text(
              LunoraLocalization.text('Сортировка'),
              style: TextStyle(color: palette.secondary, fontSize: 12),
            ),
            const SizedBox(width: 4),
            _buildSortMenu(palette),
            IconButton(
              tooltip: _descending ? 'Сначала новые' : 'Сначала старые',
              onPressed: () {
                setState(() => _descending = !_descending);
                _loadEntries();
              },
              icon: Icon(
                _descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: palette.accent,
                size: 19,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(palette, compact),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Opacity(
                      opacity: 0.82,
                      child: SvgPicture.asset(
                        LunoraThemeAssets.divider(
                          SettingsService.instance.settings.colorTheme,
                        ),
                        width: double.infinity,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.border),
                    ),
                    child: _buildToolbar(palette, compact),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 19,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        LunoraLocalization.text('Мои материалы'),
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_entries.length}',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(35),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_entries.isEmpty)
                    _buildEmptyState(palette)
                  else
                    LayoutBuilder(
                      builder: (context, listConstraints) {
                        final columns = listConstraints.maxWidth >= 780 ? 2 : 1;
                        if (columns == 1) {
                          return Column(
                            children: _entries
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildEntryCard(entry, palette),
                                  ),
                                )
                                .toList(),
                          );
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _entries.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 240,
                              ),
                          itemBuilder: (context, index) =>
                              _buildEntryCard(_entries[index], palette),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
