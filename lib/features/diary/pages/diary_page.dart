import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/lunora_theme_assets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/import_export/services/excel_service.dart';
import '../services/diary_excel_import_service.dart';
import '../models/diary_entry.dart';
import '../repositories/diary_repository.dart';
import '../../../shared/widgets/lunora_section_header.dart';
import '../../../shared/widgets/lunora_visuals.dart';
import 'diary_editor_page.dart';
import 'diary_preview_page.dart';
import '../../../core/settings/settings_service.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  static const String _contentPrefix = 'quill:v1:';
  static const String _allCategories = 'Все категории';
  static const String _allMoods = 'Любое настроение';

  final DiaryRepository _repository = DiaryRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<DiaryEntry> _entries = [];
  List<DiaryEntry> _allEntries = [];

  bool _isLoading = true;
  bool _showFavoritesOnly = false;

  String _searchQuery = '';
  String _selectedCategory = _allCategories;
  String _selectedMood = _allMoods;

  List<String> get _availableCategories {
    final categories = _allEntries
        .map((entry) => entry.category.trim())
        .where((category) => category.isNotEmpty && category != 'Без категории')
        .toSet()
        .toList();

    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return categories;
  }

  List<String> get _availableMoods {
    final moods = _allEntries
        .map((entry) => entry.mood?.trim() ?? '')
        .where((mood) => mood.isNotEmpty)
        .toSet()
        .toList();

    moods.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return moods;
  }

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

  Future<void> _importDiary() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
      );
      if (result == null || result.path == null || result.path!.isEmpty) return;
      final document = await ExcelService.instance.readWorkbook(
        File(result.path!),
      );
      final importResult = await DiaryExcelImportService.instance
          .importWorkbook(document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text(importResult.message))),
      );
      if (importResult.success) await _loadEntries();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось импортировать дневник: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);

    try {
      final allEntries = await _repository.getAll();

      List<DiaryEntry> entries;

      if (_searchQuery.isNotEmpty) {
        entries = await _repository.search(_searchQuery);
      } else {
        entries = allEntries;
      }

      if (_showFavoritesOnly) {
        entries = entries.where((entry) => entry.isFavorite).toList();
      }

      if (_selectedCategory != _allCategories) {
        entries = entries
            .where((entry) => entry.category == _selectedCategory)
            .toList();
      }

      if (_selectedMood != _allMoods) {
        entries = entries
            .where((entry) => entry.mood == _selectedMood)
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _allEntries = allEntries;
        _entries = entries;
        _isLoading = false;

        if (!_availableCategories.contains(_selectedCategory) &&
            _selectedCategory != _allCategories) {
          _selectedCategory = _allCategories;
        }

        if (!_availableMoods.contains(_selectedMood) &&
            _selectedMood != _allMoods) {
          _selectedMood = _allMoods;
        }
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

  Future<void> _openEditor({DiaryEntry? entry}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryEditorPage(entry: entry)),
    );

    if (result == true && mounted) {
      await _loadEntries();
    }
  }

  Future<void> _openPreview(DiaryEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DiaryPreviewPage(entry: entry)),
    );

    if (mounted) {
      await _loadEntries();
    }
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить запись?')),
        content: Text(
          LunoraLocalization.text(
            LunoraLocalization.text('Эта запись будет удалена без возможности восстановления.', 'This entry will be permanently deleted.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(LunoraLocalization.text('Удалить')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.delete(entry.id);
      await _loadEntries();
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

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    _loadEntries();
  }

  Future<void> _toggleFavoritesFilter() async {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });

    await _loadEntries();
  }

  Future<void> _changeCategory(String? category) async {
    if (category == null) return;

    setState(() {
      _selectedCategory = category;
    });

    await _loadEntries();
  }

  Future<void> _changeMood(String? mood) async {
    if (mood == null) return;

    setState(() {
      _selectedMood = mood;
    });

    await _loadEntries();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _entryTypeLabel(String type) {
    return type == 'memory' ? LunoraLocalization.text('Воспоминание') : LunoraLocalization.text('Дневниковая запись');
  }

  String _contentPreview(String content) {
    if (content.trim().isEmpty) return '';

    if (!content.startsWith(_contentPrefix)) {
      return content.trim();
    }

    try {
      final delta =
          jsonDecode(content.substring(_contentPrefix.length)) as List<dynamic>;

      final buffer = StringBuffer();

      for (final operation in delta) {
        if (operation is! Map<String, dynamic>) continue;

        final insert = operation['insert'];

        if (insert is String) {
          buffer.write(insert);
        } else if (insert is Map) {
          buffer.write(' ');
        }
      }

      return buffer.toString().trim();
    } catch (error) {
      debugPrint('Ошибка чтения фрагмента записи: $error');
      return LunoraLocalization.text('Не удалось отобразить текст записи.', 'Could not display the entry text.');
    }
  }

  Widget _metadataChip(String label, LunoraPalette palette, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: palette.secondary),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: palette.text)),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(LunoraPalette palette) {
    final categories = _availableCategories;

    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: LunoraLocalization.text('Категория'),
          prefixIcon: const Icon(Icons.folder_outlined),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
        items: [
          DropdownMenuItem(
            value: _allCategories,
            child: Text(LunoraLocalization.text(_allCategories)),
          ),
          ...categories.map(
            (category) => DropdownMenuItem(
              value: category,
              child: Text(category, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _changeCategory,
      ),
    );
  }

  Widget _buildMoodFilter(LunoraPalette palette) {
    final moods = _availableMoods;

    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedMood,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: LunoraLocalization.text('Настроение'),
          prefixIcon: const Icon(Icons.mood_outlined),
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
        items: [
          DropdownMenuItem(
            value: _allMoods,
            child: Text(LunoraLocalization.text(_allMoods)),
          ),
          ...moods.map(
            (mood) => DropdownMenuItem(
              value: mood,
              child: Text(mood, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: _changeMood,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LunoraSectionHeader(
                title: LunoraLocalization.text('Дневник'),
                subtitle: LunoraLocalization.text(
                  LunoraLocalization.text('Мысли, события, чувства и важные моменты.', 'Thoughts, events, feelings, and important moments.'),
                ),
                icon: Icons.menu_book_rounded,
                actions: [
                  OutlinedButton.icon(
                    onPressed: _importDiary,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(LunoraLocalization.text('Импорт Excel')),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: Text(LunoraLocalization.text('Новая запись')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const LunoraBotanicalDivider(variant: 4, height: 34),

              const SizedBox(height: 24),

              Card(
                color: palette.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: LunoraLocalization.text(
                            LunoraLocalization.text('Поиск по записям...', 'Search entries...'),
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  icon: const Icon(Icons.close),
                                )
                              : null,
                          filled: true,
                          fillColor: palette.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            avatar: Icon(
                              _showFavoritesOnly
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: _showFavoritesOnly
                                  ? Colors.pinkAccent
                                  : palette.secondary,
                            ),
                            label: Text(
                              LunoraLocalization.text('Любимые моменты'),
                            ),
                            selected: _showFavoritesOnly,
                            onSelected: (_) => _toggleFavoritesFilter(),
                            showCheckmark: false,
                          ),
                          _buildCategoryFilter(palette),
                          _buildMoodFilter(palette),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildContent(palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LunoraPalette palette) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      String title;
      String description;

      if (_searchQuery.isNotEmpty) {
        title = LunoraLocalization.text('Ничего не найдено');
        description = LunoraLocalization.text('Попробуй изменить поисковый запрос.');
      } else if (_showFavoritesOnly) {
        title = LunoraLocalization.text('Пока нет любимых моментов');
        description = LunoraLocalization.text('Отмечай сердечком важные для себя записи.');
      } else if (_selectedMood != _allMoods) {
        title = LunoraLocalization.text('Записей с таким настроением нет');
        description = LunoraLocalization.text('Выбери другое настроение или сбрось фильтр.');
      } else if (_selectedCategory != _allCategories) {
        title = LunoraLocalization.text('В этой категории пока пусто');
        description = LunoraLocalization.text('Выбери другую категорию или покажи все записи.');
      } else {
        title = LunoraLocalization.text('Пока здесь тихо');
        description = LunoraLocalization.text('Твои записи будут храниться здесь.');
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              LunoraThemeAssets.emptyState(
                SettingsService.instance.settings.colorTheme,
                _searchQuery.isNotEmpty ? 'search' : 'diary',
              ),
              width: 175,
              height: 130,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.secondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final preview = _contentPreview(entry.content);

        return Card(
          color: palette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPreview(entry),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title.isEmpty ? LunoraLocalization.text('Без названия', 'Untitled') : entry.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (entry.isFavorite) ...[
                        const Icon(
                          Icons.favorite,
                          size: 18,
                          color: Colors.pinkAccent,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatDate(entry.entryDate),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 12,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: LunoraLocalization.text('Действия'),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(entry: entry);
                          } else if (value == 'delete') {
                            _deleteEntry(entry);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              LunoraLocalization.text('Редактировать'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(LunoraLocalization.text('Удалить')),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metadataChip(
                        _entryTypeLabel(entry.entryType),
                        palette,
                        icon: entry.entryType == 'memory'
                            ? Icons.auto_awesome_outlined
                            : Icons.menu_book_outlined,
                      ),
                      if (entry.category != 'Без категории')
                        _metadataChip(
                          entry.category,
                          palette,
                          icon: Icons.folder_outlined,
                        ),
                      if (entry.mood != null && entry.mood!.isNotEmpty)
                        _metadataChip(
                          entry.mood!,
                          palette,
                          icon: Icons.mood_outlined,
                        ),
                    ],
                  ),

                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.text, height: 1.5),
                    ),
                  ],

                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.tags
                          .map(
                            (tag) => _metadataChip(
                              '#$tag',
                              palette,
                              icon: Icons.tag,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
