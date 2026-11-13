import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';

import '../models/planner_goal.dart';

class PlannerRepository {
  PlannerRepository._();

  static final PlannerRepository instance = PlannerRepository._();

  static const Uuid _uuid = Uuid();

  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  // =========================
  // ЦЕЛИ
  // =========================

  Future<List<PlannerGoal>> getGoals({
    required int month,
    required int year,
  }) async {
    final db = await _database;

    final rows = await db.query(
      'planner_goals',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'sort_order ASC, created_at ASC',
    );

    return rows.map(PlannerGoal.fromMap).toList();
  }

  Future<PlannerGoal> createGoal({
    required String title,
    required int month,
    required int year,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Название цели не может быть пустым.');
    }

    final db = await _database;
    final now = DateTime.now();

    final goal = PlannerGoal(
      id: _uuid.v4(),
      title: normalizedTitle,
      month: month,
      year: year,
      sortOrder: await _nextGoalOrder(month, year),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'planner_goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return goal;
  }

  Future<int> _nextGoalOrder(int month, int year) async {
    final db = await _database;

    final result = await db.rawQuery(
      '''
      SELECT MAX(sort_order) AS max_order
      FROM planner_goals
      WHERE month = ? AND year = ?
      ''',
      [month, year],
    );

    return ((result.first['max_order'] as int?) ?? -1) + 1;
  }

  Future<PlannerGoal> updateGoal(PlannerGoal goal) async {
    final normalizedTitle = goal.title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Название цели не может быть пустым.');
    }

    final db = await _database;

    final updated = goal.copyWith(
      title: normalizedTitle,
      updatedAt: DateTime.now(),
    );

    final count = await db.update(
      'planner_goals',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );

    if (count == 0) {
      throw StateError('Цель не найдена.');
    }

    return updated;
  }

  Future<bool> deleteGoal(String id) async {
    final db = await _database;

    final count = await db.delete(
      'planner_goals',
      where: 'id = ?',
      whereArgs: [id],
    );

    return count > 0;
  }

  // =========================
  // ЗАМЕТКИ
  // =========================

  Future<List<Map<String, Object?>>> getNotes() async {
    final db = await _database;

    return db.query(
      'notes',
      where: 'source_module = ?',
      whereArgs: ['planner'],
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, Object?>> createNote({
    required String title,
    required String content,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Название заметки не может быть пустым.');
    }

    final db = await _database;
    final now = DateTime.now();

    final note = <String, Object?>{
      'id': _uuid.v4(),
      'title': normalizedTitle,
      'content': content.trim(),
      'source_module': 'planner',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await db.insert('notes', note);

    return note;
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Название заметки не может быть пустым.');
    }

    final db = await _database;

    final count = await db.update(
      'notes',
      {
        'title': normalizedTitle,
        'content': content.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND source_module = ?',
      whereArgs: [id, 'planner'],
    );

    if (count == 0) {
      throw StateError('Заметка не найдена.');
    }
  }

  Future<bool> deleteNote(String id) async {
    final db = await _database;

    final count = await db.delete(
      'notes',
      where: 'id = ? AND source_module = ?',
      whereArgs: [id, 'planner'],
    );

    return count > 0;
  }
}
