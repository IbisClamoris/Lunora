import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/habit_entry.dart';

typedef HabitDatabaseProvider = Future<Database> Function();

class HabitRepository {
  HabitRepository._({HabitDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => LunoraDatabase.instance.database);

  @visibleForTesting
  HabitRepository.forTesting(HabitDatabaseProvider databaseProvider)
      : _databaseProvider = databaseProvider;

  static final HabitRepository instance = HabitRepository._();
  static const Uuid _uuid = Uuid();
  final HabitDatabaseProvider _databaseProvider;

  Future<Database> get _database => _databaseProvider();

  Future<List<HabitEntry>> getAll({bool includeArchived = false}) async {
    final db = await _database;
    final rows = await db.query(
      'habits',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'created_at ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(HabitEntry.fromMap).toList();
  }

  Future<HabitEntry> create({
    required String name,
    String description = '',
    int targetPerWeek = 7,
    int colorValue = 0xFF8E9BCB,
    int iconCodePoint = 0xe3a1,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Habit name cannot be empty.');
    }
    if (targetPerWeek < 1 || targetPerWeek > 7) {
      throw ArgumentError.value(targetPerWeek, 'targetPerWeek', 'Target must be between 1 and 7.');
    }
    final db = await _database;
    final now = DateTime.now();
    final habit = HabitEntry(
      id: _uuid.v4(),
      name: normalizedName,
      description: description.trim(),
      targetPerWeek: targetPerWeek,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('habits', habit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
    return habit;
  }

  Future<void> update(HabitEntry habit) async {
    final name = habit.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(habit.name, 'name', 'Habit name cannot be empty.');
    }
    if (habit.targetPerWeek < 1 || habit.targetPerWeek > 7) {
      throw ArgumentError.value(habit.targetPerWeek, 'targetPerWeek', 'Target must be between 1 and 7.');
    }
    final db = await _database;
    await db.update(
      'habits',
      habit.copyWith(name: name, updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> archive(String id, {bool archived = true}) async {
    final db = await _database;
    await db.update('habits', {
      'is_archived': archived ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> toggleCompletion(String habitId, DateTime date) async {
    final db = await _database;
    final day = _dateKey(date);
    final existing = await db.query(
      'habit_completions',
      columns: ['id'],
      where: 'habit_id = ? AND completed_on = ?',
      whereArgs: [habitId, day],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.delete('habit_completions',
          where: 'habit_id = ? AND completed_on = ?',
          whereArgs: [habitId, day]);
      return false;
    }
    await db.insert('habit_completions', {
      'id': _uuid.v4(),
      'habit_id': habitId,
      'completed_on': day,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  Future<Set<String>> getCompletionDates(
    String habitId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'habit_completions',
      columns: ['completed_on'],
      where: 'habit_id = ? AND completed_on >= ? AND completed_on <= ?',
      whereArgs: [habitId, _dateKey(from), _dateKey(to)],
      orderBy: 'completed_on ASC',
    );
    return rows.map((row) => row['completed_on'] as String).toSet();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
