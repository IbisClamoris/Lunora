import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/database.dart';
import '../models/recipe_meal_plan_entry.dart';

class RecipeMealPlanRepository {
  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  Future<List<RecipeMealPlanEntry>> getAll() async {
    final db = await _database;

    final rows = await db.query(
      'recipe_meal_plan_entries',
      orderBy: 'plan_date ASC, sort_order ASC',
    );

    return rows.map(RecipeMealPlanEntry.fromMap).toList();
  }

  Future<List<RecipeMealPlanEntry>> getForDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _database;

    final startDate = _dateKey(start);
    final endDate = _dateKey(end);

    final rows = await db.query(
      'recipe_meal_plan_entries',
      where: 'plan_date >= ? AND plan_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'plan_date ASC, sort_order ASC',
    );

    return rows.map(RecipeMealPlanEntry.fromMap).toList();
  }

  Future<List<RecipeMealPlanEntry>> getForDate(DateTime date) async {
    final db = await _database;

    final rows = await db.query(
      'recipe_meal_plan_entries',
      where: 'plan_date = ?',
      whereArgs: [_dateKey(date)],
      orderBy: 'sort_order ASC',
    );

    return rows.map(RecipeMealPlanEntry.fromMap).toList();
  }

  Future<void> create(RecipeMealPlanEntry entry) async {
    final db = await _database;

    await db.insert('recipe_meal_plan_entries', entry.toMap());
  }

  Future<void> update(RecipeMealPlanEntry entry) async {
    final db = await _database;

    await db.update(
      'recipe_meal_plan_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _database;

    return db.delete(
      'recipe_meal_plan_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteForRecipe(String recipeId) async {
    final db = await _database;

    return db.delete(
      'recipe_meal_plan_entries',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}
