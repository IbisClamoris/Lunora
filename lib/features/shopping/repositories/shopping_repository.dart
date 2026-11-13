import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../recipes/models/recipe_ingredient.dart';
import '../models/shopping_item.dart';

class ShoppingRepository {
  ShoppingRepository._();

  static final ShoppingRepository instance = ShoppingRepository._();

  static const Uuid _uuid = Uuid();

  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  Future<List<ShoppingItem>> getAll({
    bool? isPurchased,
    String? category,
    String? searchQuery,
  }) async {
    final db = await _database;

    final conditions = <String>[];
    final arguments = <dynamic>[];

    if (isPurchased != null) {
      conditions.add('is_purchased = ?');
      arguments.add(isPurchased ? 1 : 0);
    }

    if (category != null && category.trim().isNotEmpty) {
      conditions.add('category = ?');
      arguments.add(category.trim());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('''
        (
          title LIKE ?
          OR notes LIKE ?
          OR category LIKE ?
        )
      ''');

      final query = '%${searchQuery.trim()}%';
      arguments.addAll([query, query, query]);
    }

    final result = await db.query(
      'shopping_items',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'is_purchased ASC, sort_order ASC, created_at DESC',
    );

    return result.map(ShoppingItem.fromMap).toList();
  }

  Future<ShoppingItem?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return ShoppingItem.fromMap(result.first);
  }

  Future<List<ShoppingItem>> getBySource({
    required String sourceModule,
    required String sourceRecordId,
  }) async {
    final db = await _database;

    final result = await db.query(
      'shopping_items',
      where: 'source_module = ? AND source_record_id = ?',
      whereArgs: [sourceModule, sourceRecordId],
      orderBy: 'sort_order ASC',
    );

    return result.map(ShoppingItem.fromMap).toList();
  }

  Future<List<String>> getCategories() async {
    final db = await _database;

    final result = await db.rawQuery('''
      SELECT DISTINCT category
      FROM shopping_items
      WHERE category IS NOT NULL
        AND TRIM(category) != ''
      ORDER BY category COLLATE NOCASE ASC
    ''');

    return result.map((row) => row['category'] as String).toList();
  }

  Future<int> getCount({bool? isPurchased}) async {
    final db = await _database;

    final result = await db.rawQuery(
      isPurchased == null
          ? 'SELECT COUNT(*) AS total FROM shopping_items'
          : '''
            SELECT COUNT(*) AS total
            FROM shopping_items
            WHERE is_purchased = ?
          ''',
      isPurchased == null ? null : [isPurchased ? 1 : 0],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> add(ShoppingItem item) async {
    final db = await _database;
    final now = DateTime.now();

    final newItem = item.copyWith(
      id: item.id.trim().isEmpty ? _uuid.v4() : item.id,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'shopping_items',
      newItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addNew({
    required String title,
    String? category,
    double? quantity,
    String? unit,
    String? notes,
    String? sourceModule,
    String? sourceRecordId,
  }) async {
    final now = DateTime.now();

    final item = ShoppingItem(
      id: _uuid.v4(),
      title: title.trim(),
      category: category,
      quantity: quantity,
      unit: unit,
      notes: notes,
      sourceModule: sourceModule,
      sourceRecordId: sourceRecordId,
      createdAt: now,
      updatedAt: now,
    );

    await add(item);
  }

  Future<void> addRecipeIngredients({
    required String recipeId,
    required List<RecipeIngredient> ingredients,
  }) async {
    if (ingredients.isEmpty) return;

    final db = await _database;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'shopping_items',
        where: 'source_module = ? AND source_record_id = ?',
        whereArgs: ['recipe', recipeId],
      );

      final existingIngredientIds = existing
          .map((row) => row['notes'] as String?)
          .whereType<String>()
          .where((value) => value.startsWith('recipe_ingredient_id:'))
          .map((value) => value.replaceFirst('recipe_ingredient_id:', ''))
          .toSet();

      final now = DateTime.now();

      for (final ingredient in ingredients) {
        if (ingredient.name.trim().isEmpty) continue;

        if (existingIngredientIds.contains(ingredient.id)) continue;

        final ingredientNotes = ingredient.notes.trim();
        final notes = ingredientNotes.isEmpty
            ? 'recipe_ingredient_id:${ingredient.id}'
            : '$ingredientNotes\nrecipe_ingredient_id:${ingredient.id}';

        final item = ShoppingItem(
          id: _uuid.v4(),
          title: ingredient.name.trim(),
          quantity: ingredient.quantity,
          unit: ingredient.unit.trim().isEmpty ? null : ingredient.unit.trim(),
          notes: notes,
          sourceModule: 'recipe',
          sourceRecordId: recipeId,
          sortOrder: ingredient.sortOrder,
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert('shopping_items', item.toMap());
      }
    });
  }

  Future<void> update(ShoppingItem item) async {
    final db = await _database;

    final updatedItem = item.copyWith(updatedAt: DateTime.now());

    await db.update(
      'shopping_items',
      updatedItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPurchased(String id, {required bool isPurchased}) async {
    final db = await _database;
    final now = DateTime.now();

    await db.update(
      'shopping_items',
      {
        'is_purchased': isPurchased ? 1 : 0,
        'purchased_at': isPurchased ? now.toIso8601String() : null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePurchased() async {
    final db = await _database;

    await db.delete(
      'shopping_items',
      where: 'is_purchased = ?',
      whereArgs: [1],
    );
  }

  Future<void> deleteBySource({
    required String sourceModule,
    required String sourceRecordId,
  }) async {
    final db = await _database;

    await db.delete(
      'shopping_items',
      where: 'source_module = ? AND source_record_id = ?',
      whereArgs: [sourceModule, sourceRecordId],
    );
  }

  Future<void> clearAll() async {
    final db = await _database;

    await db.delete('shopping_items');
  }
}
