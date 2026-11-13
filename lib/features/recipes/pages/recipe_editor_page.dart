import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';

import 'package:uuid/uuid.dart';

import '../../../core/storage/storage_service.dart';
import '../models/recipe_entry.dart';
import '../models/recipe_ingredient.dart';
import '../repositories/recipe_repository.dart';
import '../services/recipe_metadata_service.dart';

class RecipeEditorPage extends StatefulWidget {
  final RecipeEntry? recipe;
  final RecipeImportData? importData;

  const RecipeEditorPage({super.key, this.recipe, this.importData});

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = RecipeRepository();
  final _uuid = const Uuid();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _categoryController;
  late final TextEditingController _servingsController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _reviewController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _tagsController;

  final List<_IngredientDraft> _ingredients = [];

  String? _coverPath;
  double? _rating;
  bool _isSaving = false;
  bool _isLoading = true;

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();

    final recipe = widget.recipe;

    final imported = widget.importData;
    _titleController = TextEditingController(
      text: recipe?.title ?? imported?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: recipe?.description ?? imported?.description ?? '',
    );
    _instructionsController = TextEditingController(
      text: recipe?.instructions ?? imported?.instructions ?? '',
    );
    _categoryController = TextEditingController(text: recipe?.category ?? '');
    _servingsController = TextEditingController(
      text: '${recipe?.servings ?? imported?.servings ?? 2}',
    );
    _prepTimeController = TextEditingController(
      text:
          recipe?.prepTimeMinutes?.toString() ??
          imported?.prepTimeMinutes?.toString() ??
          '',
    );
    _cookTimeController = TextEditingController(
      text:
          recipe?.cookTimeMinutes?.toString() ??
          imported?.cookTimeMinutes?.toString() ??
          '',
    );
    _reviewController = TextEditingController(text: recipe?.review ?? '');
    _sourceUrlController = TextEditingController(
      text: recipe?.sourceUrl ?? imported?.sourceUrl ?? '',
    );
    _tagsController = TextEditingController(
      text: recipe?.tags.join(', ') ?? '',
    );

    _coverPath = recipe?.coverPath ?? imported?.coverPath;
    _rating = recipe?.rating;

    _loadIngredients();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _categoryController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _reviewController.dispose();
    _sourceUrlController.dispose();
    _tagsController.dispose();

    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }

    super.dispose();
  }

  Future<void> _loadIngredients() async {
    if (widget.recipe != null) {
      try {
        final ingredients = await _repository.getIngredients(widget.recipe!.id);

        if (!mounted) return;

        _ingredients.addAll(
          ingredients.map(
            (ingredient) => _IngredientDraft.fromIngredient(ingredient),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LunoraLocalization.text(
                'Не удалось загрузить ингредиенты: $error',
              ),
            ),
          ),
        );
      }
    }

    if (widget.recipe == null && widget.importData != null) {
      for (final ingredient in widget.importData!.ingredients) {
        final draft = _IngredientDraft();
        draft.nameController.text = ingredient.name;
        draft.quantityController.text = ingredient.quantity?.toString() ?? '';
        draft.unitController.text = ingredient.unit;
        draft.notesController.text = ingredient.notes;
        _ingredients.add(draft);
      }
    }

    if (!mounted) return;

    setState(() => _isLoading = false);
  }

  Future<void> _pickCover() async {
    final files = await FilePicker.pickFiles(type: FileType.image);

    if (files.isEmpty || files.first.path == null) return;

    final sourceFile = File(files.first.path!);

    try {
      final coversDirectory = await StorageService.instance.coversDirectory;

      final extension = sourceFile.path.contains('.')
          ? sourceFile.path.split('.').last
          : 'jpg';

      final fileName = 'recipe_${_uuid.v4()}.$extension';
      final destination =
          '${coversDirectory.path}${Platform.pathSeparator}$fileName';

      final copiedFile = await sourceFile.copy(destination);

      if (!mounted) return;

      setState(() => _coverPath = copiedFile.path);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить фотографию: $error'),
          ),
        ),
      );
    }
  }

  void _removeCover() {
    setState(() => _coverPath = null);
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientDraft());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  List<RecipeIngredient> _buildIngredients(String recipeId, DateTime now) {
    final result = <RecipeIngredient>[];

    for (final draft in _ingredients) {
      final name = draft.nameController.text.trim();

      if (name.isEmpty) continue;

      final quantityText = draft.quantityController.text.trim().replaceAll(
        ',',
        '.',
      );

      final quantity = double.tryParse(quantityText);

      result.add(
        RecipeIngredient(
          id: draft.id ?? _uuid.v4(),
          recipeId: recipeId,
          name: name,
          quantity: quantity,
          unit: draft.unitController.text.trim(),
          notes: draft.notesController.text.trim(),
          sortOrder: result.length,
          createdAt: draft.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    return result;
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final existing = widget.recipe;
      final recipeId = existing?.id ?? _uuid.v4();

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      final recipe = RecipeEntry(
        id: recipeId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim(),
        coverPath: _coverPath,
        category: _categoryController.text.trim().isEmpty
            ? 'Без категории'
            : _categoryController.text.trim(),
        tags: tags,
        servings: int.tryParse(_servingsController.text) ?? 2,
        prepTimeMinutes: int.tryParse(_prepTimeController.text),
        cookTimeMinutes: int.tryParse(_cookTimeController.text),
        rating: _rating,
        review: _reviewController.text.trim(),
        sourceUrl: _sourceUrlController.text.trim().isEmpty
            ? null
            : _sourceUrlController.text.trim(),
        sourceName: existing?.sourceName ?? widget.importData?.sourceName ?? '',
        isFavorite: existing?.isFavorite ?? false,
        sortOrder: existing?.sortOrder ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final ingredients = _buildIngredients(recipeId, now);

      if (existing == null) {
        await _repository.create(recipe, ingredients: ingredients);
      } else {
        await _repository.update(recipe);
        await _repository.replaceIngredients(recipeId, ingredients);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить рецепт: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Фотография блюда', Icons.image_outlined),
        if (_coverPath != null && File(_coverPath!).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_coverPath!),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, size: 48),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickCover,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                LunoraLocalization.text('Выбрать фото', 'Choose photo'),
              ),
            ),
            if (_coverPath != null)
              TextButton.icon(
                onPressed: _removeCover,
                icon: const Icon(Icons.delete_outline),
                label: Text(LunoraLocalization.text('Убрать', 'Remove')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ингредиенты', Icons.shopping_basket_outlined),
        if (_ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              LunoraLocalization.text(
                'Добавь продукты, необходимые для блюда.',
                'Add the ingredients needed for this dish.',
              ),
            ),
          ),
        ...List.generate(_ingredients.length, (index) {
          final ingredient = _ingredients[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          LunoraLocalization.text('Ингредиент ${index + 1}'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: LunoraLocalization.text('Удалить ингредиент'),
                        onPressed: () => _removeIngredient(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  TextField(
                    controller: ingredient.nameController,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название продукта'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ingredient.quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: LunoraLocalization.text('Количество'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: ingredient.unitController,
                          decoration: InputDecoration(
                            labelText: LunoraLocalization.text('Единица'),
                            hintText: LunoraLocalization.text('г, мл, шт.'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ingredient.notesController,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Примечание'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add),
          label: Text(
            LunoraLocalization.text('Добавить ингредиент', 'Add ingredient'),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Моя оценка', Icons.star_outline),
        Wrap(
          spacing: 4,
          children: List.generate(5, (index) {
            final value = index + 1;

            return IconButton(
              tooltip: LunoraLocalization.text('$value из 5'),
              onPressed: () {
                setState(() {
                  _rating = _rating == value.toDouble()
                      ? null
                      : value.toDouble();
                });
              },
              icon: Icon(
                _rating != null && _rating! >= value
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
                size: 30,
              ),
            );
          }),
        ),
        Text(
          _rating == null
              ? 'Оценка не поставлена'
              : 'Оценка: ${_rating!.toStringAsFixed(0)} из 5',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование рецепта' : 'Новый рецепт'),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Сохранить'),
            onPressed: _isSaving || _isLoading ? null : _saveRecipe,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: LunoraLocalization.text('Название рецепта'),
                    hint: 'Например, домашняя паста',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введи название рецепта';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _descriptionController,
                    label: LunoraLocalization.text('Краткое описание'),
                    hint: 'Что это за блюдо?',
                    maxLines: 2,
                  ),
                  _buildCoverSection(),
                  _buildSectionTitle('Основная информация', Icons.tune),
                  _buildTextField(
                    controller: _categoryController,
                    label: LunoraLocalization.text('Категория'),
                    hint: 'Завтраки, обеды, десерты...',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _servingsController,
                          label: LunoraLocalization.text('Порции'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final servings = int.tryParse(value ?? '');
                            if (servings == null || servings < 1) {
                              return 'Минимум 1';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _prepTimeController,
                          label: LunoraLocalization.text('Подготовка, мин.'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _cookTimeController,
                    label: LunoraLocalization.text('Приготовление, мин.'),
                    keyboardType: TextInputType.number,
                  ),
                  _buildIngredientsSection(),
                  _buildSectionTitle('Приготовление', Icons.menu_book_outlined),
                  _buildTextField(
                    controller: _instructionsController,
                    label: LunoraLocalization.text('Шаги приготовления'),
                    hint: 'Опиши процесс приготовления...',
                    maxLines: 8,
                  ),
                  _buildSectionTitle('Дополнительно', Icons.bookmark_outline),
                  _buildTextField(
                    controller: _tagsController,
                    label: LunoraLocalization.text('Теги'),
                    hint: 'быстро, семейное, на каждый день',
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _sourceUrlController,
                    label: LunoraLocalization.text('Ссылка на источник'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _reviewController,
                    label: LunoraLocalization.text('Мои заметки и впечатления'),
                    maxLines: 3,
                  ),
                  _buildRatingSection(),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveRecipe,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Сохранение...' : 'Сохранить рецепт',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _IngredientDraft {
  final String? id;
  final DateTime? createdAt;

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController notesController;

  _IngredientDraft({this.id, this.createdAt})
    : nameController = TextEditingController(),
      quantityController = TextEditingController(),
      unitController = TextEditingController(),
      notesController = TextEditingController();

  factory _IngredientDraft.fromIngredient(RecipeIngredient ingredient) {
    final draft = _IngredientDraft(
      id: ingredient.id,
      createdAt: ingredient.createdAt,
    );

    draft.nameController.text = ingredient.name;
    draft.quantityController.text = ingredient.quantity?.toString() ?? '';
    draft.unitController.text = ingredient.unit;
    draft.notesController.text = ingredient.notes;

    return draft;
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    notesController.dispose();
  }
}
