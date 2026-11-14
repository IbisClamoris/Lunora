import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/lunora_theme_assets.dart';

import '../../../core/localization/lunora_localization.dart';
import '../../../core/theme/app_theme.dart';

import 'recipe_web_search_page.dart';
import '../models/recipe_entry.dart';
import '../repositories/recipe_repository.dart';
import '../services/recipe_excel_import_service.dart';
import 'recipe_details_page.dart';
import 'recipe_editor_page.dart';
import 'recipe_excel_import_page.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final RecipeRepository _repository = RecipeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<RecipeEntry> _recipes = [];
  List<String> _categories = [];

  String _selectedCategory = LunoraLocalization.text('Все', 'All');
  bool _favoritesOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final recipes = await _repository.getAll(
        searchQuery: _searchController.text,
        category: _selectedCategory,
        favoritesOnly: _favoritesOnly,
      );

      final categories = await _repository.getCategories();

      if (!mounted) return;

      setState(() {
        _recipes = recipes;
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить рецепты: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _openImport() async {
    final result = await Navigator.of(context).push<RecipeExcelImportResult>(
      MaterialPageRoute(builder: (context) => const RecipeExcelImportPage()),
    );

    if (!mounted || result == null) return;

    await _loadRecipes();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LunoraLocalization.text(result.message)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _openExternalSearch() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecipeWebSearchPage()),
    );
    if (result == true && mounted) {
      await _loadRecipes();
    }
  }

  Future<void> _openEditor({RecipeEntry? recipe}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => RecipeEditorPage(recipe: recipe)),
    );

    if (result == true && mounted) {
      await _loadRecipes();
    }
  }

  Future<void> _openDetails(RecipeEntry recipe) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RecipeDetailsPage(recipe: recipe),
      ),
    );

    if (result == true && mounted) {
      await _loadRecipes();
    }
  }

  Future<void> _toggleFavorite(RecipeEntry recipe) async {
    try {
      await _repository.setFavorite(recipe.id, !recipe.isFavorite);

      await _loadRecipes();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось изменить избранное: $error'),
          ),
        ),
      );
    }
  }

  String _formatTime(RecipeEntry recipe) {
    final total = (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0);

    if (total <= 0) {
      return LunoraLocalization.text('Время не указано', 'Time not specified');
    }
    if (total < 60) return '$total ${LunoraLocalization.text('мин.')}';

    final hours = total ~/ 60;
    final minutes = total % 60;

    if (minutes == 0) return '$hours ${LunoraLocalization.text('ч.')}';

    return '$hours ${LunoraLocalization.text('ч.')} $minutes ${LunoraLocalization.text('мин.')}';
  }

  Widget _buildCategorySelector() {
    final categories = [LunoraLocalization.text('Все', 'All'), ..._categories];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = _selectedCategory == category;

          final palette = Theme.of(context).extension<LunoraPalette>()!;
          return ChoiceChip(
            label: Text(
              category == LunoraLocalization.text('Все', 'All') ? LunoraLocalization.text('Все') : category,
            ),
            selected: selected,
            showCheckmark: true,
            selectedColor: palette.accentSoft,
            backgroundColor: palette.surface,
            side: BorderSide(color: selected ? palette.accent : palette.border),
            labelStyle: TextStyle(
              color: palette.text,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onSelected: (_) {
              setState(() => _selectedCategory = category);
              _loadRecipes();
            },
          );
        },
      ),
    );
  }

  Widget _buildRecipeCard(RecipeEntry recipe) {
    final theme = Theme.of(context);
    final palette = theme.extension<LunoraPalette>()!;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.text.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(recipe),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (recipe.coverPath != null && recipe.coverPath!.isNotEmpty)
                    Image.file(
                      File(recipe.coverPath!),
                      height: 158,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildCoverPlaceholder(),
                    )
                  else
                    _buildCoverPlaceholder(),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: palette.surface.withValues(alpha: 0.94),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: LunoraLocalization.text(
                          recipe.isFavorite
                              ? LunoraLocalization.text('Убрать из избранного', 'Remove from favourites')
                              : LunoraLocalization.text('В избранное', 'Add to favourites'),
                        ),
                        onPressed: () => _toggleFavorite(recipe),
                        icon: Icon(
                          recipe.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: recipe.isFavorite
                              ? palette.rose
                              : palette.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(17, 14, 17, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          recipe.category.isEmpty
                              ? LunoraLocalization.text('Без категории')
                              : recipe.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (recipe.description.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Expanded(
                          child: Text(
                            recipe.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.secondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _buildInfo(
                            Icons.schedule_rounded,
                            _formatTime(recipe),
                          ),
                          _buildInfo(
                            Icons.people_alt_outlined,
                            '${recipe.servings} ${LunoraLocalization.text("порц.")}',
                          ),
                          if (recipe.rating != null)
                            _buildInfo(
                              Icons.star_rounded,
                              recipe.rating!.toStringAsFixed(1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    return Container(
      height: 158,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accentSoft,
            palette.surface,
            palette.rose.withValues(alpha: 0.16),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 50,
            color: palette.accent.withValues(alpha: 0.72),
          ),
          Positioned(
            bottom: 10,
            right: 14,
            child: Icon(
              Icons.auto_awesome,
              size: 18,
              color: palette.accent.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              LunoraThemeAssets.emptyState(
                SettingsService.instance.settings.colorTheme,
                'recipes',
              ),
              width: 180,
              height: 135,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              _favoritesOnly
                  ? LunoraLocalization.text('В избранном пока пусто')
                  : LunoraLocalization.text('Здесь пока нет рецептов'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text('Твои любимые блюда будут собраны здесь'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!_favoritesOnly)
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: Text(LunoraLocalization.text('Добавить рецепт')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: LunoraLocalization.text('Добавить рецепт'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecipes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LunoraLocalization.text(
                              LunoraLocalization.text('Моя книга рецептов', 'My recipe book'),
                              'My recipe book',
                            ),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: LunoraLocalization.text(
                            LunoraLocalization.text('Найти рецепты в интернете', 'Find recipes online'),
                          ),
                          onPressed: _openExternalSearch,
                          icon: const Icon(Icons.travel_explore_rounded),
                        ),
                        IconButton(
                          tooltip: LunoraLocalization.text(
                            LunoraLocalization.text('Импортировать из Excel', 'Import from Excel'),
                          ),
                          onPressed: _openImport,
                          icon: const Icon(Icons.file_upload_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LunoraLocalization.text(
                        LunoraLocalization.text('Коллекция блюд, которые хочется готовить снова', 'A collection of dishes worth making again'),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _loadRecipes(),
                      decoration: InputDecoration(
                        hintText: LunoraLocalization.text('Найти рецепт...'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadRecipes();
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategorySelector(),
                    const SizedBox(height: 12),
                    FilterChip(
                      label: Text(LunoraLocalization.text('Только избранное')),
                      selected: _favoritesOnly,
                      avatar: const Icon(Icons.favorite_border, size: 18),
                      onSelected: (value) {
                        setState(() => _favoritesOnly = value);
                        _loadRecipes();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recipes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 1000
                        ? 3
                        : width >= 650
                        ? 2
                        : 1;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 350,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildRecipeCard(_recipes[index]);
                      }, childCount: _recipes.length),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
