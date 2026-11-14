import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/lunora_theme_assets.dart';

import '../../../shared/widgets/lunora_section_header.dart';

import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/import_export/services/excel_service.dart';
import '../models/book_entry.dart';
import '../repositories/book_repository.dart';
import '../services/book_excel_import_service.dart';
import 'book_details_page.dart';
import 'book_editor_page.dart';
import 'book_web_search_page.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final BookRepository _repository = BookRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<BookEntry>> _booksFuture;

  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBooks() {
    _booksFuture = _repository.getAll();
  }

  Future<void> _refresh() async {
    setState(_loadBooks);
    await _booksFuture;
  }

  Future<void> _importBooks() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
      );

      if (result == null || result.path == null) {
        return;
      }

      final file = File(result.path!);

      final document = await ExcelService.instance.readWorkbook(file);

      final importResult = await BookExcelImportService.instance.importWorkbook(
        document,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text(importResult.message))),
      );

      if (importResult.success) {
        await _refresh();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LunoraLocalization.text('Ошибка импорта: $error')),
        ),
      );
    }
  }

  Future<void> _openWebSearch() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const BookWebSearchPage()));
    if (mounted) await _refresh();
  }

  Future<void> _openEditor({BookEntry? book}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => BookEditorPage(book: book)),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _changeBookStatus(BookEntry book, String status) async {
    if (book.status == status) return;
    try {
      await _repository.updateStatus(book.id, status);
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Не удалось изменить статус: $error'))),
      );
    }
  }

  Future<void> _openDetails(BookEntry book) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => BookDetailsPage(book: book)),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  List<BookEntry> _filterBooks(List<BookEntry> books) {
    var result = books;

    if (_selectedFilter == 'favorites') {
      result = result.where((book) => book.isFavorite).toList();
    } else if (_selectedFilter != 'all') {
      result = result.where((book) => book.status == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      result = result.where((book) {
        return book.title.toLowerCase().contains(query) ||
            book.authors.toLowerCase().contains(query) ||
            book.genre.toLowerCase().contains(query) ||
            book.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    return result;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return 'Читаю';
      case 'completed':
        return 'Прочитано';
      case 'planned':
        return 'В планах';
      default:
        return 'Неизвестно';
    }
  }

  Color _statusColor(String status, LunoraPalette palette) {
    switch (status) {
      case 'reading':
        return palette.accent;
      case 'completed':
        return const Color(0xFF8A9F85);
      case 'planned':
        return const Color(0xFFB39BC8);
      default:
        return palette.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return FutureBuilder<List<BookEntry>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        final books = snapshot.data ?? [];

        final readingCount = books
            .where((book) => book.status == 'reading')
            .length;

        final completedCount = books
            .where((book) => book.status == 'completed')
            .length;

        final plannedCount = books
            .where((book) => book.status == 'planned')
            .length;

        final filteredBooks = _filterBooks(books);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(palette),
              const SizedBox(height: 28),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                _buildError(palette, snapshot.error.toString())
              else ...[
                _buildStatistics(
                  palette,
                  total: books.length,
                  reading: readingCount,
                  completed: completedCount,
                  planned: plannedCount,
                ),
                const SizedBox(height: 30),
                _buildCurrentlyReading(
                  palette,
                  books.where((book) => book.status == 'reading').toList(),
                ),
                const SizedBox(height: 30),
                _buildLibraryHeader(palette),
                const SizedBox(height: 16),
                _buildSearch(palette),
                const SizedBox(height: 16),
                _buildFilters(palette),
                const SizedBox(height: 20),
                if (filteredBooks.isEmpty)
                  _buildEmptyState(palette)
                else
                  _buildBookList(palette, filteredBooks),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(LunoraPalette palette) {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Книжный мир'),
      subtitle: LunoraLocalization.text(
        'Твоя личная библиотека и история чтения',
      ),
      icon: Icons.auto_stories_rounded,
      actions: [
        IconButton(
          tooltip: LunoraLocalization.text('Найти книги в интернете'),
          onPressed: _openWebSearch,
          icon: const Icon(Icons.travel_explore_rounded),
        ),
        IconButton(
          tooltip: LunoraLocalization.text('Добавить книгу'),
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: LunoraLocalization.text('Импортировать из Excel'),
          onPressed: _importBooks,
          icon: const Icon(Icons.file_upload_outlined),
        ),
        IconButton(
          tooltip: LunoraLocalization.text('Обновить'),
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildStatistics(
    LunoraPalette palette, {
    required int total,
    required int reading,
    required int completed,
    required int planned,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 850 ? 4 : 2;
        const spacing = 14.0;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        final items = [
          _StatisticData(
            'Всего книг',
            total,
            Icons.menu_book_rounded,
            palette.accent,
          ),
          _StatisticData(
            'Читаю сейчас',
            reading,
            Icons.auto_stories_rounded,
            const Color(0xFF8A9F85),
          ),
          _StatisticData(
            'Прочитано',
            completed,
            Icons.check_circle_outline_rounded,
            const Color(0xFFB39BC8),
          ),
          _StatisticData(
            'В планах',
            planned,
            Icons.bookmark_border_rounded,
            const Color(0xFFC69B9B),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _buildStatisticCard(palette, item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatisticCard(LunoraPalette palette, _StatisticData item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value.toString(),
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  LunoraLocalization.text(item.label),
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyReading(LunoraPalette palette, List<BookEntry> books) {
    if (books.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(palette, LunoraLocalization.text('Сейчас читаю'), Icons.auto_stories_rounded),
        const SizedBox(height: 14),
        ...books.map(
          (book) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReadingCard(palette, book),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingCard(LunoraPalette palette, BookEntry book) {
    final progress = book.progress.clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(book),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.sagePanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              _buildCover(book, width: 62, height: 88),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.authors.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        book.authors,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: palette.border,
                        valueColor: AlwaysStoppedAnimation(palette.accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.pageCount != null
                          ? '${book.currentPage} из ${book.pageCount} страниц'
                          : '${book.currentPage} страниц',
                      style: TextStyle(color: palette.secondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${book.progressPercent}%',
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryHeader(LunoraPalette palette) {
    return _sectionTitle(
      palette,
      'Моя библиотека',
      Icons.library_books_rounded,
    );
  }

  Widget _buildSearch(LunoraPalette palette) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim();
        });
      },
      style: TextStyle(color: palette.text),
      decoration: InputDecoration(
        hintText: LunoraLocalization.text('Найти книгу, автора или жанр...'),
        hintStyle: TextStyle(color: palette.secondary),
        prefixIcon: Icon(Icons.search_rounded, color: palette.secondary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: Icon(Icons.close_rounded, color: palette.secondary),
              )
            : null,
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
    );
  }

  Widget _buildFilters(LunoraPalette palette) {
    final filters = [
      ('all', 'Все'),
      ('reading', 'Читаю'),
      ('completed', 'Прочитано'),
      ('planned', 'В планах'),
      ('favorites', 'Избранное'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter.$1;
                });
              },
              selectedColor: palette.sagePanel,
              backgroundColor: palette.surface,
              checkmarkColor: palette.accent,
              side: BorderSide(
                color: selected ? palette.accent : palette.border,
              ),
              labelStyle: TextStyle(
                color: selected ? palette.accent : palette.secondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookList(LunoraPalette palette, List<BookEntry> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 570
            ? 2
            : 1;

        const spacing = 14.0;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: books.map((book) {
            return SizedBox(
              width: cardWidth,
              child: _buildBookCard(palette, book),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBookCard(LunoraPalette palette, BookEntry book) {
    final statusColor = _statusColor(book.status, palette);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(book),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(book, width: 76, height: 112),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: book.isFavorite
                              ? 'Убрать из избранного'
                              : 'В избранное',
                          onPressed: () async {
                            await _repository.toggleFavorite(book.id);
                            if (mounted) {
                              await _refresh();
                            }
                          },
                          icon: Icon(
                            book.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: book.isFavorite
                                ? const Color(0xFFC58F9B)
                                : palette.secondary,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                    if (book.authors.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.authors,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    PopupMenuButton<String>(
                      tooltip: LunoraLocalization.text('Быстро изменить статус'),
                      onSelected: (value) => _changeBookStatus(book, value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'planned',
                          child: Text(LunoraLocalization.text('В планах')),
                        ),
                        PopupMenuItem(value: 'reading', child: Text(LunoraLocalization.text('Читаю'))),
                        PopupMenuItem(
                          value: 'completed',
                          child: Text(LunoraLocalization.text('Прочитано')),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              LunoraLocalization.text(
                                _statusLabel(book.status),
                              ),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (book.genre.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        book.genre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (book.rating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFD5AD70),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            book.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(
    BookEntry book, {
    required double width,
    required double height,
  }) {
    final path = book.coverPath;

    if (path != null && path.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _coverPlaceholder(width, height);
          },
        ),
      );
    }

    return _coverPlaceholder(width, height);
  }

  Widget _coverPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7E9DF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: Color(0xFF899783),
        size: 29,
      ),
    );
  }

  Widget _buildEmptyState(LunoraPalette palette) {
    final isSearching = _searchQuery.isNotEmpty;
    final isFiltered = _selectedFilter != 'all';

    String title;
    String description;

    if (isSearching) {
      title = LunoraLocalization.text('Ничего не найдено');
      description = LunoraLocalization.text('Попробуй изменить поисковый запрос');
    } else if (isFiltered) {
      title = LunoraLocalization.text('Здесь пока пусто');
      description = LunoraLocalization.text('В этой категории пока нет книг');
    } else {
      title = LunoraLocalization.text('Твоя библиотека пока пуста');
      description = LunoraLocalization.text('Здесь будут храниться книги, которые ты читаешь');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            LunoraThemeAssets.emptyState(
              SettingsService.instance.settings.colorTheme,
              isSearching ? 'search' : 'books',
            ),
            width: 170,
            height: 125,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.secondary, fontSize: 12),
          ),
          if (!isSearching && !isFiltered) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(LunoraLocalization.text('Добавить первую книгу')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(LunoraPalette palette, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade300,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            LunoraLocalization.text('Не удалось загрузить библиотеку'),
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: palette.secondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(LunoraLocalization.text('Повторить')),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(LunoraPalette palette, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: palette.accent, size: 20),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatisticData {
  const _StatisticData(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}
