import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book_entry.dart';
import '../repositories/book_repository.dart';
import 'book_editor_page.dart';

class BookDetailsPage extends StatefulWidget {
  final BookEntry book;

  const BookDetailsPage({super.key, required this.book});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late BookEntry _book;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);

    try {
      final updatedBook = await BookRepository.instance.getById(_book.id);

      if (updatedBook != null && mounted) {
        setState(() => _book = updatedBook);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось обновить книгу: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editBook() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => BookEditorPage(book: _book)),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _deleteBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Удалить книгу?')),
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Книга «${_book.title}» будет удалена из библиотеки.', 'Book “${_book.title}” will be removed from the library.'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: Text(LunoraLocalization.text('Удалить')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await BookRepository.instance.delete(_book.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось удалить книгу: $e');
      }
    }
  }

  Future<void> _changeProgress() async {
    final controller = TextEditingController(
      text: _book.currentPage.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Прогресс чтения')),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: LunoraLocalization.text('Прочитано страниц'),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());

                if (value == null || value < 0) {
                  return;
                }

                if (_book.pageCount != null && value > _book.pageCount!) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    try {
      final updatedBook = _book.copyWith(currentPage: result);

      await BookRepository.instance.update(updatedBook);

      if (mounted) {
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось обновить прогресс: $e');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await BookRepository.instance.toggleFavorite(_book.id);

      if (mounted) {
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось изменить избранное: $e');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading':
        return LunoraLocalization.text('Читаю', 'Reading');
      case 'completed':
        return LunoraLocalization.text('Прочитано', 'Read');
      case 'planned':
        return LunoraLocalization.text('В планах', 'Planned');
      default:
        return LunoraLocalization.text('Неизвестно', 'Unknown');
    }
  }

  Color _statusColor(ColorScheme colors) {
    switch (_book.status) {
      case 'reading':
        return colors.primary;
      case 'completed':
        return const Color(0xFF789477);
      case 'planned':
        return const Color(0xFFAA8DBD);
      default:
        return colors.secondary;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не указана';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('О книге')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Избранное'),
            onPressed: _toggleFavorite,
            icon: Icon(
              _book.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _book.isFavorite ? const Color(0xFFC58F9B) : null,
            ),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Редактировать'),
            onPressed: _editBook,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Удалить'),
            onPressed: _deleteBook,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookHeader(colors),
                    const SizedBox(height: 30),

                    if (_book.status == 'reading') ...[
                      _buildProgressSection(colors),
                      const SizedBox(height: 30),
                    ],

                    if (_book.description.isNotEmpty) ...[
                      _sectionTitle(LunoraLocalization.text('Описание'), Icons.description_outlined),
                      const SizedBox(height: 12),
                      _textCard(colors, _book.description),
                      const SizedBox(height: 26),
                    ],

                    _sectionTitle(LunoraLocalization.text('Информация'), Icons.info_outline_rounded),
                    const SizedBox(height: 12),
                    _buildInformation(colors),
                    const SizedBox(height: 26),

                    if (_book.tags.isNotEmpty) ...[
                      _sectionTitle(LunoraLocalization.text('Теги'), Icons.sell_outlined),
                      const SizedBox(height: 12),
                      _buildTags(colors),
                      const SizedBox(height: 26),
                    ],

                    if (_book.review.isNotEmpty) ...[
                      _sectionTitle(
                        LunoraLocalization.text('Мои впечатления', 'My thoughts'),
                        Icons.rate_review_outlined,
                      ),
                      const SizedBox(height: 12),
                      _textCard(colors, _book.review),
                      const SizedBox(height: 26),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: colors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildBookHeader(ColorScheme colors) {
    final statusColor = _statusColor(colors);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;

          final cover = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                _book.coverPath != null && File(_book.coverPath!).existsSync()
                ? Image.file(
                    File(_book.coverPath!),
                    width: 140,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return _coverPlaceholder(colors);
                    },
                  )
                : _coverPlaceholder(colors),
          );

          final information = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _book.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_book.authors.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    _book.authors,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _statusLabel(_book.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_book.genre.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _book.genre,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
                if (_book.rating != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD5AD70),
                        size: 23,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_book.rating!.toStringAsFixed(1)} / 10',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: cover),
                const SizedBox(height: 22),
                information,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [cover, const SizedBox(width: 24), information],
          );
        },
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Container(
      width: 140,
      height: 200,
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.menu_book_rounded,
        size: 60,
        color: colors.primary.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildProgressSection(ColorScheme colors) {
    final progress = _book.progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LunoraLocalization.text('Прогресс чтения'),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_book.progressPercent}%',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _book.pageCount != null
                      ? LunoraLocalization.text('${_book.currentPage} из ${_book.pageCount} страниц', '${_book.currentPage} of ${_book.pageCount} pages')
                      : LunoraLocalization.text('${_book.currentPage} страниц прочитано', '${_book.currentPage} pages read'),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _changeProgress,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(LunoraLocalization.text('Изменить')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformation(ColorScheme colors) {
    final items = <(String, String, IconData)>[
      if (_book.seriesName.trim().isNotEmpty)
        (
          LunoraLocalization.text('Серия', 'Series'),
          _book.seriesNumber == null
              ? _book.seriesName
              : '${_book.seriesName} · № ${_book.seriesNumber}',
          Icons.auto_stories_outlined,
        ),
      (
        LunoraLocalization.text('Жанр', 'Genre'),
        _book.genre.isEmpty ? LunoraLocalization.text('Не указан', 'Not specified') : _book.genre,
        Icons.category_outlined,
      ),
      (
        LunoraLocalization.text('Начало чтения', 'Started reading'),
        _formatDate(_book.startedAt),
        Icons.calendar_today_outlined,
      ),
      (
        LunoraLocalization.text('Завершение чтения', 'Finished reading'),
        _formatDate(_book.finishedAt),
        Icons.event_available_outlined,
      ),
      (
        LunoraLocalization.text('Всего страниц', 'Total pages'),
        _book.pageCount?.toString() ?? LunoraLocalization.text('Не указано', 'Not specified'),
        Icons.menu_book_outlined,
      ),
      (
        LunoraLocalization.text('Прочитано страниц', 'Pages read'),
        _book.currentPage.toString(),
        Icons.bookmark_outline_rounded,
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].$3, color: colors.primary),
              title: Text(
                items[i].$1,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              subtitle: Text(
                items[i].$2,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (i != items.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTags(ColorScheme colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _book.tags.map((tag) {
        return Chip(
          label: Text(tag),
          backgroundColor: colors.surfaceContainerLow,
          side: BorderSide(color: colors.outlineVariant),
          labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        );
      }).toList(),
    );
  }

  Widget _textCard(ColorScheme colors, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SelectableText(
        text,
        style: TextStyle(color: colors.onSurface, height: 1.6, fontSize: 14),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
