import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../shopping/repositories/shopping_repository.dart';
import '../models/wishlist_entry.dart';
import '../repositories/wishlist_repository.dart';

class WishlistDetailsPage extends StatefulWidget {
  const WishlistDetailsPage({super.key, required this.entry});

  final WishlistEntry entry;

  @override
  State<WishlistDetailsPage> createState() => _WishlistDetailsPageState();
}

class _WishlistDetailsPageState extends State<WishlistDetailsPage> {
  final WishlistRepository _repository = WishlistRepository();
  final _formKey = GlobalKey<FormState>();

  late WishlistEntry _entry;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  late final TextEditingController _priceController;
  late final TextEditingController _currencyController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _notesController;

  String _priority = 'normal';
  DateTime? _desiredDate;

  bool _isLoading = false;
  bool _isAddingToShoppingList = false;

  @override
  void initState() {
    super.initState();

    _entry = widget.entry;

    _titleController = TextEditingController(text: _entry.title);
    _descriptionController = TextEditingController(text: _entry.description);
    _categoryController = TextEditingController(text: _entry.category);
    _tagsController = TextEditingController(text: _entry.tags.join(', '));
    _priceController = TextEditingController(
      text: _entry.price?.toString() ?? '',
    );
    _currencyController = TextEditingController(text: _entry.currency);
    _sourceUrlController = TextEditingController(text: _entry.sourceUrl ?? '');
    _notesController = TextEditingController(text: _entry.notes);

    _priority = _entry.priority;
    _desiredDate = _entry.desiredDate;
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не указана';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _priorityLabel() {
    switch (_entry.priority) {
      case 'high':
        return 'Высокий';
      case 'low':
        return 'Низкий';
      default:
        return 'Обычный';
    }
  }

  Color _priorityColor(LunoraPalette palette) {
    switch (_entry.priority) {
      case 'high':
        return const Color(0xFFCB8585);
      case 'low':
        return const Color(0xFF91A99A);
      default:
        return palette.accent;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final priceText = _priceController.text.trim().replaceAll(',', '.');
    final price = priceText.isEmpty ? null : double.tryParse(priceText);

    if (priceText.isNotEmpty && price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Проверь стоимость'))),
      );
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final sourceUrl = _sourceUrlController.text.trim();

    final updatedEntry = _entry.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'Без категории'
          : _categoryController.text.trim(),
      tags: tags,
      price: price,
      clearPrice: price == null,
      currency: _currencyController.text.trim(),
      sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
      clearSourceUrl: sourceUrl.isEmpty,
      priority: _priority,
      desiredDate: _desiredDate,
      clearDesiredDate: _desiredDate == null,
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      await _repository.update(updatedEntry);

      if (!mounted) return;

      await _refreshEntry();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Изменения сохранены'))),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить изменения: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshEntry() async {
    final updated = await _repository.getById(_entry.id);

    if (!mounted || updated == null) return;

    setState(() {
      _entry = updated;
    });
  }

  Future<void> _togglePurchased() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newStatus = !_entry.isPurchased;

      await _repository.setPurchased(_entry.id, isPurchased: newStatus);

      final shoppingRepository = ShoppingRepository.instance;

      final linkedItems = await shoppingRepository.getBySource(
        sourceModule: 'wishlist',
        sourceRecordId: _entry.id,
      );

      for (final item in linkedItems) {
        await shoppingRepository.setPurchased(item.id, isPurchased: newStatus);
      }

      await _refreshEntry();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось обновить статус: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addToShoppingList() async {
    if (_isAddingToShoppingList || _isLoading) return;

    setState(() {
      _isAddingToShoppingList = true;
    });

    try {
      final shoppingRepository = ShoppingRepository.instance;

      final existing = await shoppingRepository.getBySource(
        sourceModule: 'wishlist',
        sourceRecordId: _entry.id,
      );

      if (existing.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LunoraLocalization.text(
                  'Это желание уже есть в списке покупок',
                ),
              ),
            ),
          );
        }
        return;
      }

      final notes = [
        if (_entry.description.trim().isNotEmpty) _entry.description.trim(),
        if (_entry.notes.trim().isNotEmpty) _entry.notes.trim(),
        if (_entry.price != null)
          'Стоимость: ${_entry.price} ${_entry.currency}',
        if (_entry.sourceUrl?.trim().isNotEmpty == true)
          'Источник: ${_entry.sourceUrl!.trim()}',
      ].join('\n');

      await shoppingRepository.addNew(
        title: _entry.title,
        category: _entry.category,
        quantity: 1,
        notes: notes.isEmpty ? null : notes,
        sourceModule: 'wishlist',
        sourceRecordId: _entry.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LunoraLocalization.text('Добавлено в список покупок')),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось добавить товар: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToShoppingList = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _desiredDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: LunoraLocalization.text('Выбери желаемую дату'),
      cancelText: LunoraLocalization.text('Отмена'),
      confirmText: LunoraLocalization.text('Выбрать'),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _desiredDate = selected;
    });
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Удалить желание?')),
          content: Text(
            LunoraLocalization.text(
              'Запись будет удалена из Вишлиста. Это действие нельзя отменить.',
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.delete(_entry.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось удалить желание: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _openSource() async {
    final source = _entry.sourceUrl?.trim();

    if (source == null || source.isEmpty) return;

    final uri = Uri.tryParse(source);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Некорректная ссылка'))),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LunoraLocalization.text('Не удалось открыть ссылку')),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Ошибка открытия ссылки: $error'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(LunoraLocalization.text('Желание')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Удалить'),
            onPressed: _isLoading ? null : _deleteEntry,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(palette),
                  const SizedBox(height: 24),
                  _buildTitleSection(palette),
                  const SizedBox(height: 24),
                  _buildEditableInformation(palette),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _descriptionController,
                    label: LunoraLocalization.text('Описание'),
                    palette: palette,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _notesController,
                    label: LunoraLocalization.text('Заметки'),
                    palette: palette,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _tagsController,
                    label: LunoraLocalization.text('Теги'),
                    palette: palette,
                    hint: 'Через запятую',
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _sourceUrlController,
                    label: LunoraLocalization.text('Ссылка на источник'),
                    palette: palette,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 20),
                  _buildDatePicker(palette),
                  const SizedBox(height: 24),
                  if (_entry.sourceUrl != null &&
                      _entry.sourceUrl!.trim().isNotEmpty) ...[
                    _buildSource(palette),
                    const SizedBox(height: 24),
                  ],
                  _buildDates(palette),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        LunoraLocalization.text('Сохранить изменения'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading || _isAddingToShoppingList
                          ? null
                          : _addToShoppingList,
                      icon: _isAddingToShoppingList
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart),
                      label: Text(
                        _isAddingToShoppingList
                            ? 'Добавление...'
                            : 'Добавить в список покупок',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _togglePurchased,
                      icon: Icon(
                        _entry.isPurchased
                            ? Icons.undo
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        _entry.isPurchased
                            ? 'Вернуть в желания'
                            : 'Отметить как купленное',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(LunoraPalette palette) {
    final path = _entry.imagePath;

    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null && path.isNotEmpty && File(path).existsSync()
          ? Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _imagePlaceholder(palette);
              },
            )
          : _imagePlaceholder(palette),
    );
  }

  Widget _imagePlaceholder(LunoraPalette palette) {
    return Center(
      child: Icon(
        Icons.auto_awesome_outlined,
        size: 65,
        color: palette.secondary.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildTitleSection(LunoraPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(_entry.category, palette.accent),
            _chip(_priorityLabel(), _priorityColor(palette)),
            if (_entry.isPurchased) _chip('Куплено', const Color(0xFF91A99A)),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _titleController,
          label: LunoraLocalization.text('Название желания'),
          palette: palette,
          fontSize: 22,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Укажи название желания';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEditableInformation(LunoraPalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LunoraLocalization.text('Информация'), palette),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _categoryController,
            label: LunoraLocalization.text('Категория'),
            palette: palette,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: _inputDecoration('Приоритет', palette),
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
              if (value != null) {
                setState(() {
                  _priority = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _priceController,
            label: LunoraLocalization.text('Стоимость'),
            palette: palette,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _currencyController,
            label: LunoraLocalization.text('Валюта'),
            palette: palette,
            hint: 'Например, EUR, USD, RUB',
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(LunoraPalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LunoraLocalization.text('Желаемая дата'), palette),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(_desiredDate),
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: LunoraLocalization.text('Выбрать дату'),
                onPressed: _selectDate,
                icon: Icon(
                  Icons.calendar_month_outlined,
                  color: palette.accent,
                ),
              ),
              if (_desiredDate != null)
                IconButton(
                  tooltip: LunoraLocalization.text('Очистить дату'),
                  onPressed: () {
                    setState(() {
                      _desiredDate = null;
                    });
                  },
                  icon: Icon(Icons.close, color: palette.secondary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required LunoraPalette palette,
    String? hint,
    int maxLines = 1,
    double fontSize = 14,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: palette.text, fontSize: fontSize),
      decoration: _inputDecoration(label, palette).copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDecoration(String label, LunoraPalette palette) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.secondary),
      filled: true,
      fillColor: palette.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.secondary.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
    );
  }

  Widget _buildSource(LunoraPalette palette) {
    return _sectionContainer(
      palette,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LunoraLocalization.text('Открыть сохранённый источник'), palette),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openSource,
              child: Row(
                children: [
                  Icon(Icons.open_in_new, color: palette.accent, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _entry.sourceUrl!,
                      style: TextStyle(
                        color: palette.accent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDates(LunoraPalette palette) {
    return _sectionContainer(
      palette,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LunoraLocalization.text('История'), palette),
          const SizedBox(height: 12),
          _dateRow('Добавлено', _formatDate(_entry.createdAt), palette),
          const SizedBox(height: 8),
          _dateRow('Приобретено', _formatDate(_entry.purchasedAt), palette),
        ],
      ),
    );
  }

  Widget _dateRow(String label, String value, LunoraPalette palette) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: palette.secondary)),
        ),
        Text(
          value,
          style: TextStyle(color: palette.text, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _sectionContainer(LunoraPalette palette, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, LunoraPalette palette) {
    return Text(
      title,
      style: TextStyle(
        color: palette.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
