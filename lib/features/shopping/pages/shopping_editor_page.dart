import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/shopping_item.dart';
import '../repositories/shopping_repository.dart';

class ShoppingEditorPage extends StatefulWidget {
  final ShoppingItem? item;

  const ShoppingEditorPage({super.key, this.item});

  @override
  State<ShoppingEditorPage> createState() => _ShoppingEditorPageState();
}

class _ShoppingEditorPageState extends State<ShoppingEditorPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    if (item != null) {
      _titleController.text = item.title;
      _categoryController.text = item.category ?? '';
      _quantityController.text = item.quantity == null
          ? ''
          : _formatQuantity(item.quantity!);
      _unitController.text = item.unit ?? '';
      _notesController.text = item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      final quantityText = _quantityController.text.trim().replaceAll(',', '.');

      final quantity = quantityText.isEmpty
          ? null
          : double.tryParse(quantityText);

      final item = widget.item;

      if (item == null) {
        final newItem = ShoppingItem(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          category: _nullableText(_categoryController.text),
          quantity: quantity,
          unit: _nullableText(_unitController.text),
          notes: _nullableText(_notesController.text),
          createdAt: now,
          updatedAt: now,
        );

        await ShoppingRepository.instance.add(newItem);
      } else {
        final updatedItem = item.copyWith(
          title: _titleController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          quantity: quantity,
          unit: _nullableText(_unitController.text),
          notes: _nullableText(_notesController.text),
          updatedAt: now,
          clearCategory: _categoryController.text.trim().isEmpty,
          clearQuantity: quantity == null,
          clearUnit: _unitController.text.trim().isEmpty,
          clearNotes: _notesController.text.trim().isEmpty,
        );

        await ShoppingRepository.instance.update(updatedItem);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить товар: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование товара' : 'Новый товар'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionTitle('Основная информация'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Название товара *'),
                    hintText: LunoraLocalization.text('Например, молоко'),
                    prefixIcon: Icon(Icons.shopping_basket_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название товара';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Категория'),
                    hintText: LunoraLocalization.text(
                      'Например, Молочные продукты',
                    ),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),
                _buildSectionTitle('Количество'),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Количество'),
                          hintText: '1',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) return null;

                          final parsed = double.tryParse(
                            text.replaceAll(',', '.'),
                          );

                          if (parsed == null || parsed <= 0) {
                            return 'Введите число больше нуля';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text(
                            'Единица измерения',
                          ),
                          hintText: LunoraLocalization.text('шт., кг, л...'),
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _buildSectionTitle('Дополнительно'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Заметки'),
                    hintText: LunoraLocalization.text(
                      'Дополнительная информация о товаре',
                    ),
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Сохранение...' : 'Сохранить товар'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(LunoraLocalization.text('Отмена')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
