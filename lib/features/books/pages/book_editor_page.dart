import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/storage_service.dart';
import '../models/book_entry.dart';
import '../repositories/book_repository.dart';

class BookEditorPage extends StatefulWidget {
  final BookEntry? book;

  const BookEditorPage({super.key, this.book});

  @override
  State<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends State<BookEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _authorsController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _genreController;
  late final TextEditingController _seriesNameController;
  late final TextEditingController _seriesNumberController;
  late final TextEditingController _tagsController;
  late final TextEditingController _pageCountController;
  late final TextEditingController _currentPageController;
  late final TextEditingController _reviewController;

  late String _status;
  String? _coverPath;
  double? _rating;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  bool _isFavorite = false;
  bool _isSaving = false;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();

    final book = widget.book;

    _titleController = TextEditingController(text: book?.title ?? '');
    _authorsController = TextEditingController(text: book?.authors ?? '');
    _descriptionController = TextEditingController(
      text: book?.description ?? '',
    );
    _genreController = TextEditingController(text: book?.genre ?? '');
    _seriesNameController = TextEditingController(text: book?.seriesName ?? '');
    _seriesNumberController = TextEditingController(
      text: book?.seriesNumber?.toString() ?? '',
    );
    _tagsController = TextEditingController(text: book?.tags.join(', ') ?? '');
    _pageCountController = TextEditingController(
      text: book?.pageCount?.toString() ?? '',
    );
    _currentPageController = TextEditingController(
      text: book?.currentPage.toString() ?? '0',
    );
    _reviewController = TextEditingController(text: book?.review ?? '');

    _status = book?.status ?? 'planned';
    _coverPath = book?.coverPath;
    _rating = book?.rating;
    _startedAt = book?.startedAt;
    _finishedAt = book?.finishedAt;
    _isFavorite = book?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorsController.dispose();
    _descriptionController.dispose();
    _genreController.dispose();
    _seriesNameController.dispose();
    _seriesNumberController.dispose();
    _tagsController.dispose();
    _pageCountController.dispose();
    _currentPageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);

      if (file == null || file.path == null) {
        return;
      }

      setState(() {
        _coverPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось выбрать обложку: $e'),
          ),
        ),
      );
    }
  }

  /// Копирует выбранную обложку в постоянное хранилище Lunora.
  Future<String?> _prepareCoverPath() async {
    final sourcePath = _coverPath;

    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw Exception(LunoraLocalization.text('Файл обложки не найден: $sourcePath', 'Cover image file not found: $sourcePath'));
    }

    final coversDirectory = await StorageService.instance.coversDirectory;

    final normalizedSource = p.normalize(p.absolute(sourceFile.path));

    final normalizedCovers = p.normalize(p.absolute(coversDirectory.path));

    // Если обложка уже находится в постоянном хранилище,
    // оставляем существующий путь.
    if (p.isWithin(normalizedCovers, normalizedSource)) {
      return sourceFile.path;
    }

    final extension = p.extension(sourcePath);
    final fileName =
        'book_cover_${DateTime.now().microsecondsSinceEpoch}$extension';

    final destinationPath = p.join(coversDirectory.path, fileName);

    final copiedFile = await sourceFile.copy(destinationPath);

    return copiedFile.path;
  }

  Future<void> _pickDate({
    required DateTime? currentDate,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 10),
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final pageCount = int.tryParse(_pageCountController.text.trim());
    final seriesNumberText = _seriesNumberController.text.trim();
    final seriesNumber = double.tryParse(seriesNumberText.replaceAll(',', '.'));
    if (seriesNumberText.isNotEmpty && seriesNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Номер книги в серии должен быть числом.'),
          ),
        ),
      );
      return;
    }
    final currentPage = int.tryParse(_currentPageController.text.trim()) ?? 0;

    if (pageCount != null && currentPage > pageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Количество прочитанных страниц не может превышать общее количество.', 'Pages read cannot exceed the total page count.'),
            ),
          ),
        ),
      );
      return;
    }

    if (pageCount != null && pageCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Количество страниц не может быть отрицательным.', 'Page count cannot be negative.'),
            ),
          ),
        ),
      );
      return;
    }

    if (currentPage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Количество прочитанных страниц не может быть отрицательным.', 'Pages read cannot be negative.'),
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final oldBook = widget.book;

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      // Переносим обложку в постоянную папку Lunora.
      final permanentCoverPath = await _prepareCoverPath();

      final book = BookEntry(
        id: oldBook?.id ?? '',
        title: _titleController.text.trim(),
        authors: _authorsController.text.trim(),
        description: _descriptionController.text.trim(),
        coverPath: permanentCoverPath,
        genre: _genreController.text.trim(),
        seriesName: _seriesNameController.text.trim(),
        seriesNumber: seriesNumber,
        tags: tags,
        status: _status,
        rating: _rating,
        review: _reviewController.text.trim(),
        startedAt: _startedAt,
        finishedAt: _finishedAt,
        pageCount: pageCount,
        currentPage: currentPage,
        isFavorite: _isFavorite,
        createdAt: oldBook?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await BookRepository.instance.update(book);
      } else {
        await BookRepository.instance.create(book);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить книгу: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? LunoraLocalization.text('Редактирование книги') : LunoraLocalization.text('Новая книга')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Сохранить'),
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(colors),
                  const SizedBox(height: 28),

                  _sectionTitle(LunoraLocalization.text('Основная информация')),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _titleController,
                    label: LunoraLocalization.text('Название книги'),
                    required: true,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _authorsController,
                    label: LunoraLocalization.text('Автор'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _genreController,
                    label: LunoraLocalization.text('Жанр'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _seriesNameController,
                    label: LunoraLocalization.text('Серия'),
                    hint: LunoraLocalization.text('Например, Вселенная Гришей', 'For example, The Universe of Grisha'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _seriesNumberController,
                    label: LunoraLocalization.text('Номер книги в серии'),
                    hint: LunoraLocalization.text('Например, 1 или 1.5', 'For example, 1 or 1.5'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _descriptionController,
                    label: LunoraLocalization.text('Описание'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _tagsController,
                    label: LunoraLocalization.text('Теги'),
                    hint: LunoraLocalization.text('Фэнтези, магия, классика', 'Fantasy, magic, classics'),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle(LunoraLocalization.text('Чтение')),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Статус'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'planned',
                        child: Text(LunoraLocalization.text('В планах')),
                      ),
                      DropdownMenuItem(
                        value: 'reading',
                        child: Text(LunoraLocalization.text('Читаю')),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text(LunoraLocalization.text('Прочитано')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _pageCountController,
                          label: LunoraLocalization.text('Всего страниц'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildTextField(
                          controller: _currentPageController,
                          label: LunoraLocalization.text('Прочитано страниц'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDateTile(
                    title: LunoraLocalization.text('Начало чтения'),
                    date: _startedAt,
                    onTap: () => _pickDate(
                      currentDate: _startedAt,
                      onSelected: (date) {
                        setState(() => _startedAt = date);
                      },
                    ),
                    onClear: () {
                      setState(() => _startedAt = null);
                    },
                  ),

                  _buildDateTile(
                    title: LunoraLocalization.text('Завершение чтения'),
                    date: _finishedAt,
                    onTap: () => _pickDate(
                      currentDate: _finishedAt,
                      onSelected: (date) {
                        setState(() => _finishedAt = date);
                      },
                    ),
                    onClear: () {
                      setState(() => _finishedAt = null);
                    },
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle(LunoraLocalization.text('Оценка и впечатления')),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<double?>(
                    initialValue: _rating,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Оценка'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<double?>(
                        value: null,
                        child: Text(LunoraLocalization.text('Без оценки')),
                      ),
                      ...List.generate(10, (index) {
                        final rating = (index + 1).toDouble();

                        return DropdownMenuItem<double?>(
                          value: rating,
                          child: Text('$rating / 10'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _rating = value);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _reviewController,
                    label: LunoraLocalization.text('Мой отзыв'),
                    maxLines: 5,
                  ),

                  const SizedBox(height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      LunoraLocalization.text('Добавить в избранное'),
                    ),
                    secondary: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: colors.primary,
                    ),
                    value: _isFavorite,
                    onChanged: (value) {
                      setState(() => _isFavorite = value);
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isEditing ? LunoraLocalization.text('Сохранить изменения', 'Save changes') : LunoraLocalization.text('Добавить книгу', 'Add book'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colors) {
    final hasCover =
        _coverPath != null &&
        _coverPath!.isNotEmpty &&
        File(_coverPath!).existsSync();

    return Center(
      child: Column(
        children: [
          Container(
            width: 150,
            height: 210,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasCover
                ? Image.file(
                    File(_coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return _coverPlaceholder(colors);
                    },
                  )
                : _coverPlaceholder(colors),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _pickCover,
            icon: const Icon(Icons.image_outlined),
            label: Text(LunoraLocalization.text('Выбрать обложку')),
          ),
          if (_coverPath != null)
            TextButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(() => _coverPath = null);
                    },
              icon: const Icon(Icons.delete_outline),
              label: Text(LunoraLocalization.text('Убрать обложку')),
            ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        size: 64,
        color: colors.primary.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return LunoraLocalization.text('Заполни это поле', 'Fill in this field');
              }

              return null;
            }
          : null,
    );
  }

  Widget _buildDateTile({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final formattedDate = date == null
        ? LunoraLocalization.text('Не указана', 'Not specified')
        : '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.year}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(formattedDate),
      leading: const Icon(Icons.calendar_today_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: LunoraLocalization.text('Выбрать дату'),
            onPressed: onTap,
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
          if (date != null)
            IconButton(
              tooltip: LunoraLocalization.text('Очистить дату'),
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
