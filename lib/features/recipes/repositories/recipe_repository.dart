import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/database.dart';
import '../models/recipe_entry.dart';
import '../models/recipe_ingredient.dart';

class RecipeRepository {
  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  Future<List<RecipeEntry>> getAll({
    String? searchQuery,
    String? category,
    bool favoritesOnly = false,
  }) async {
    final db = await _database;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR description LIKE ? OR tags LIKE ?)');
      final query = '%${searchQuery.trim()}%';
      arguments.addAll([query, query, query]);
    }

    if (category != null && category != 'Все') {
      conditions.add('category = ?');
      arguments.add(category);
    }

    if (favoritesOnly) {
      conditions.add('is_favorite = 1');
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    final result = await db.query(
      'recipe_entries',
      where: where,
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'sort_order ASC, updated_at DESC',
    );

    return result.map(RecipeEntry.fromMap).toList();
  }

  Future<RecipeEntry?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      'recipe_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return RecipeEntry.fromMap(result.first);
  }

  Future<void> create(
    RecipeEntry recipe, {
    List<RecipeIngredient> ingredients = const [],
  }) async {
    final db = await _database;

    await db.transaction((txn) async {
      await txn.insert('recipe_entries', recipe.toMap());

      for (final ingredient in ingredients) {
        await txn.insert('recipe_ingredients', ingredient.toMap());
      }
    });
  }

  Future<void> update(RecipeEntry recipe) async {
    final db = await _database;

    await db.update(
      'recipe_entries',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _database;

    return db.delete('recipe_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(String id, bool isFavorite) async {
    final db = await _database;

    await db.update(
      'recipe_entries',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecipeIngredient>> getIngredients(String recipeId) async {
    final db = await _database;

    final result = await db.query(
      'recipe_ingredients',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'sort_order ASC, created_at ASC',
    );

    return result.map(RecipeIngredient.fromMap).toList();
  }

  Future<void> addIngredient(RecipeIngredient ingredient) async {
    final db = await _database;

    await db.insert('recipe_ingredients', ingredient.toMap());
  }

  Future<void> updateIngredient(RecipeIngredient ingredient) async {
    final db = await _database;

    await db.update(
      'recipe_ingredients',
      ingredient.toMap(),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );
  }

  Future<int> deleteIngredient(String id) async {
    final db = await _database;

    return db.delete('recipe_ingredients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceIngredients(
    String recipeId,
    List<RecipeIngredient> ingredients,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      await txn.delete(
        'recipe_ingredients',
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
      );

      for (final ingredient in ingredients) {
        await txn.insert('recipe_ingredients', ingredient.toMap());
      }
    });
  }

  Future<List<String>> getCategories() async {
    final db = await _database;

    final result = await db.rawQuery('''
      SELECT DISTINCT category
      FROM recipe_entries
      WHERE category != ''
      ORDER BY category COLLATE NOCASE ASC
    ''');

    return result.map((row) => row['category'] as String).toList();
  }
}
