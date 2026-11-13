import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wishlist_entry.dart';
import '../repositories/wishlist_repository.dart';

class WishlistEditorPage extends StatefulWidget {
  const WishlistEditorPage({super.key, this.entry});

  final WishlistEntry? entry;

  @override
  State<WishlistEditorPage> createState() => _WishlistEditorPageState();
}

class _WishlistEditorPageState extends State<WishlistEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = WishlistRepository();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late final TextEditingController _priceController;
  late final TextEditingController _currencyController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _notesController;

  String _priority = 'normal';
  String? _imagePath;
  String? _newImagePath;
  DateTime? _desiredDate;

  bool _removeImage = false;
  bool _saving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;

    _titleController = TextEditingController(text: entry?.title ?? '');
    _descriptionController = TextEditingController(
      text: entry?.description ?? '',
    );
    _categoryController = TextEditingController(text: entry?.category ?? '');
    _tagsController = TextEditingController(text: entry?.tags.join(', ') ?? '');
    _priceController = TextEditingController(
      text: entry?.price?.toString() ?? '',
    );
    _currencyController = TextEditingController(text: entry?.currency ?? '');
    _sourceUrlController = TextEditingController(text: entry?.sourceUrl ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');

    _priority = entry?.priority ?? 'normal';
    _imagePath = entry?.imagePath;
    _desiredDate = entry?.desiredDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _sourceUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);

    if (files.isEmpty) return;

    final path = files.single.path;
    if (path == null) return;

    setState(() {
      _newImagePath = path;
      _removeImage = false;
    });
  }

  Future<String?> _saveImage() async {
    if (_removeImage) return null;

    if (_newImagePath == null) {
      return _imagePath;
    }

    final source = File(_newImagePath!);

    if (!await source.exists()) {
      return _imagePath;
    }

    final directory = await StorageService.instance.coversDirectory;

    final extension = p.extension(source.path);
    final fileName = 'wishlist_${const Uuid().v4()}$extension';
    final destination = File(p.join(directory.path, fileName));

    await source.copy(destination.path);

    return destination.path;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _desiredDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );

    if (selectedDate == null) return;

    setState(() {
      _desiredDate = selectedDate;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now();
      final imagePath = await _saveImage();

      final priceText = _priceController.text.trim().replaceAll(',', '.');
      final price = priceText.isEmpty ? null : double.tryParse(priceText);

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (_isEditing) {
        final updatedEntry = widget.entry!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imagePath: imagePath,
          clearImagePath: imagePath == null,
          category: _categoryController.text.trim().isEmpty
              ? 'Без категории'
              : _categoryController.text.trim(),
          tags: tags,
          price: price,
          clearPrice: price == null,
          currency: _currencyController.text.trim(),
          sourceUrl: _sourceUrlController.text.trim(),
          priority: _priority,
          desiredDate: _desiredDate,
          clearDesiredDate: _desiredDate == null,
          notes: _notesController.text.trim(),
          updatedAt: now,
        );

        await _repository.update(updatedEntry);
      } else {
        final entry = WishlistEntry(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imagePath: imagePath,
          category: _categoryController.text.trim().isEmpty
              ? 'Без категории'
              : _categoryController.text.trim(),
          tags: tags,
          price: price,
          currency: _currencyController.text.trim(),
          sourceUrl: _sourceUrlController.text.trim(),
          priority: _priority,
          desiredDate: _desiredDate,
          isPurchased: false,
          purchasedAt: null,
          notes: _notesController.text.trim(),
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        );

        await _repository.create(entry);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить желание: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать желание' : 'Новое желание'),
        backgroundColor: palette.background,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildImageSection(palette),
            const SizedBox(height: 24),
            _buildSectionTitle('Основное'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Название *'),
                hintText: LunoraLocalization.text(
                  'Что хочется добавить в свою жизнь?',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Описание'),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Категория'),
                hintText: LunoraLocalization.text(
                  'Например, Техника, Книги, Дом',
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Теги'),
                hintText: LunoraLocalization.text('Через запятую'),
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionTitle('Стоимость и приоритет'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Цена'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;

                      final parsed = double.tryParse(text.replaceAll(',', '.'));

                      if (parsed == null || parsed < 0) {
                        return 'Некорректная цена';
                      }

                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _currencyController,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Валюта'),
                      hintText: 'EUR',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Приоритет'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'high',
                  child: Text(LunoraLocalization.text('Высокий')),
                ),
                DropdownMenuItem(
                  value: 'normal',
                  child: Text(LunoraLocalization.text('Обычный')),
                ),
                DropdownMenuItem(
                  value: 'low',
                  child: Text(LunoraLocalization.text('Низкий')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _priority = value;
                });
              },
            ),
            const SizedBox(height: 28),
            _buildSectionTitle('Дополнительно'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _desiredDate == null
                    ? 'Желаемая дата'
                    : 'Желаемая дата: ${_formatDate(_desiredDate!)}',
              ),
            ),
            if (_desiredDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _desiredDate = null;
                    });
                  },
                  child: Text(LunoraLocalization.text('Убрать дату')),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _sourceUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text(
                  'Ссылка на товар или источник',
                ),
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Заметки'),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(LunoraLocalization.text('Отмена')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(LunoraPalette palette) {
    final currentPath = _newImagePath ?? (_removeImage ? null : _imagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Изображение'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.secondary.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: currentPath != null && File(currentPath).existsSync()
              ? Image.file(
                  File(currentPath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    );
                  },
                )
              : const Center(child: Icon(Icons.image_outlined, size: 48)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(LunoraLocalization.text('Выбрать изображение')),
              ),
            ),
            if (currentPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: LunoraLocalization.text('Убрать изображение'),
                onPressed: () {
                  setState(() {
                    _newImagePath = null;
                    _imagePath = null;
                    _removeImage = true;
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
