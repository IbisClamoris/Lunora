import 'dart:io';
import 'package:lunora/core/localization/lunora_localization.dart';

import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../shopping/repositories/shopping_repository.dart';
import '../models/recipe_entry.dart';
import '../models/recipe_ingredient.dart';
import '../repositories/recipe_repository.dart';
import 'recipe_editor_page.dart';

class RecipeDetailsPage extends StatefulWidget {
  final RecipeEntry recipe;

  const RecipeDetailsPage({super.key, required this.recipe});

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  final RecipeRepository _repository = RecipeRepository();

  late RecipeEntry _recipe;
  List<RecipeIngredient> _ingredients = [];

  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isAddingIngredients = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    try {
      final recipe = await _repository.getById(_recipe.id);

      if (recipe == null) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      final ingredients = await _repository.getIngredients(_recipe.id);

      if (!mounted) return;

      setState(() {
        _recipe = recipe;
        _ingredients = ingredients;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(LunoraLocalization.text('Не удалось загрузить рецепт: $e', 'Could not load recipe: $e'));
    }
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RecipeEditorPage(recipe: _recipe),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      await _loadRecipe();
    }
  }

  Future<void> _toggleFavorite() async {
    final newValue = !_recipe.isFavorite;

    try {
      await _repository.setFavorite(_recipe.id, newValue);

      if (!mounted) return;

      setState(() {
        _recipe = _recipe.copyWith(
          isFavorite: newValue,
          updatedAt: DateTime.now(),
        );
      });
    } catch (e) {
      _showMessage(LunoraLocalization.text('Не удалось изменить избранное: $e', 'Could not update favourites: $e'));
    }
  }

  Future<void> _addIngredientsToShoppingList() async {
    if (_ingredients.isEmpty || _isAddingIngredients) return;

    setState(() {
      _isAddingIngredients = true;
    });

    try {
      await ShoppingRepository.instance.addRecipeIngredients(
        recipeId: _recipe.id,
        ingredients: _ingredients,
      );

      if (!mounted) return;

      _showMessage(LunoraLocalization.text('Ингредиенты добавлены в список покупок.', 'Ingredients added to the shopping list.'));
    } catch (e) {
      if (mounted) {
        _showMessage(LunoraLocalization.text('Не удалось добавить ингредиенты: $e', 'Could not add ingredients: $e'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingIngredients = false;
        });
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            LunoraLocalization.text('Удалить рецепт?', 'Delete recipe?'),
          ),
          content: Text(
            LunoraLocalization.text(
              LunoraLocalization.text('Рецепт «${_recipe.title}» будет удалён вместе со списком ингредиентов.', 'Recipe “${_recipe.title}” will be deleted together with its ingredients.'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LunoraLocalization.text('Отмена', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(LunoraLocalization.text('Удалить', 'Delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _repository.delete(_recipe.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showMessage(LunoraLocalization.text('Не удалось удалить рецепт: $e', 'Could not delete recipe: $e'));
    }
  }

  Future<void> _openSource() async {
    final source = _recipe.sourceUrl?.trim();

    if (source == null || source.isEmpty) return;

    final uri = Uri.tryParse(source);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _showMessage(LunoraLocalization.text('Некорректная ссылка на источник', 'Invalid source link'));
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        _showMessage(LunoraLocalization.text('Не удалось открыть ссылку', 'Could not open link'));
      }
    } catch (e) {
      if (mounted) {
        _showMessage(LunoraLocalization.text('Ошибка при открытии ссылки: $e', 'Error opening link: $e'));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return 'Не указано';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return LunoraLocalization.text('$remainingMinutes мин.', '$remainingMinutes min');
    }

    if (remainingMinutes == 0) {
      return LunoraLocalization.text('$hours ч.', '$hours hr');
    }

    return LunoraLocalization.text('$hours ч. $remainingMinutes мин.', '$hours hr $remainingMinutes min');
  }

  String _formatQuantity(double? quantity) {
    if (quantity == null) return '';

    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: colors.primary, size: 21),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: colors.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const minCardWidth = 190.0;

        final columns = constraints.maxWidth >= minCardWidth * 2 + spacing
            ? 2
            : 1;

        final cardWidth = columns == 2
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        final cards = [
          _buildInfoCard(Icons.people_outline, LunoraLocalization.text('Порции', 'Servings'), '${_recipe.servings}'),
          _buildInfoCard(
            Icons.timer_outlined,
            LunoraLocalization.text('Подготовка', 'Preparation'),
            _formatDuration(_recipe.prepTimeMinutes),
          ),
          _buildInfoCard(
            Icons.soup_kitchen_outlined,
            LunoraLocalization.text('Приготовление', 'Cooking'),
            _formatDuration(_recipe.cookTimeMinutes),
          ),
          _buildInfoCard(
            Icons.restaurant_menu,
            LunoraLocalization.text('Ингредиенты', 'Ingredients'),
            '${_ingredients.length}',
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(width: cardWidth, child: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildIngredients() {
    final colors = Theme.of(context).colorScheme;

    if (_ingredients.isEmpty) {
      return Text(
        LunoraLocalization.text('Ингредиенты пока не добавлены.'),
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colors.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _ingredients.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ingredients[i].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_ingredients[i].notes.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                _ingredients[i].notes,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        [
                          _formatQuantity(_ingredients[i].quantity),
                          _ingredients[i].unit,
                        ].where((value) => value.isNotEmpty).join(' '),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != _ingredients.length - 1)
                  Divider(
                    height: 1,
                    indent: 36,
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isAddingIngredients
                ? null
                : _addIngredientsToShoppingList,
            icon: _isAddingIngredients
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_shopping_cart),
            label: Text(
              _isAddingIngredients
                  ? LunoraLocalization.text('Добавление...', 'Adding...')
                  : LunoraLocalization.text('Добавить ингредиенты в список покупок', 'Add ingredients to shopping list'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    if (_recipe.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recipe.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCover() {
    final path = _recipe.coverPath;

    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(path),
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined, size: 42),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRating() {
    if (_recipe.rating == null) {
      return const SizedBox.shrink();
    }

    final rating = _recipe.rating!.clamp(0, 5);
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (index) {
          IconData icon;

          if (index < fullStars) {
            icon = Icons.star_rounded;
          } else if (index == fullStars && hasHalfStar) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }

          return Icon(icon, color: Colors.amber.shade700, size: 22);
        }),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Рецепт', 'Recipe')),
        actions: [
          IconButton(
            tooltip: _recipe.isFavorite
                ? LunoraLocalization.text('Убрать из избранного', 'Remove from favourites')
                : LunoraLocalization.text('В избранное', 'Add to favourites'),
            onPressed: _toggleFavorite,
            icon: Icon(
              _recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _recipe.isFavorite ? Colors.pink : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _openEditor();
              } else if (value == 'delete') {
                _deleteRecipe();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined),
                    const SizedBox(width: 10),
                    Text(LunoraLocalization.text('Редактировать', 'Edit')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Text(LunoraLocalization.text('Удалить', 'Delete')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCover(),

                      Text(
                        _recipe.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),

                      if (_recipe.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _recipe.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 17,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _recipe.category,
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      if (_recipe.rating != null) ...[
                        const SizedBox(height: 12),
                        _buildRating(),
                      ],

                      const SizedBox(height: 22),

                      _buildInfoCards(),

                      if (_recipe.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(LunoraLocalization.text('Теги'), icon: Icons.sell_outlined),
                        _buildTags(),
                      ],

                      const SizedBox(height: 28),

                      _buildSectionTitle(
                        LunoraLocalization.text('Ингредиенты', 'Ingredients'),
                        icon: Icons.shopping_basket_outlined,
                      ),
                      _buildIngredients(),

                      if (_recipe.instructions.trim().isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildSectionTitle(
                          LunoraLocalization.text('Приготовление', 'Cooking'),
                          icon: Icons.menu_book_outlined,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            _recipe.instructions,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(height: 1.7),
                          ),
                        ),
                      ],

                      if (_recipe.review.trim().isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildSectionTitle(
                          LunoraLocalization.text('Мои заметки', 'My notes'),
                          icon: Icons.edit_note,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _recipe.review,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.6),
                          ),
                        ),
                      ],

                      if (_recipe.sourceUrl != null &&
                          _recipe.sourceUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildSectionTitle(LunoraLocalization.text('Источник'), icon: Icons.link),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openSource,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.open_in_new,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _recipe.sourceUrl!,
                                      style: TextStyle(
                                        color: colors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                if (_isDeleting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _isLoading || _isDeleting
          ? null
          : FloatingActionButton.extended(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
              label: Text(LunoraLocalization.text('Редактировать', 'Edit')),
            ),
    );
  }
}
