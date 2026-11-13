import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/diary_entry.dart';

typedef DiaryDatabaseProvider = Future<Database> Function();

class DiaryRepository {
  DiaryRepository._({DiaryDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final DiaryRepository instance = DiaryRepository._();

  static const Uuid _uuid = Uuid();

  final DiaryDatabaseProvider _databaseProvider;

  Future<List<DiaryEntry>> getAll() async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<DiaryEntry?> getById(String id) async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return DiaryEntry.fromMap(result.first);
  }

  Future<List<DiaryEntry>> getByDate(DateTime date) async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'entry_date = ?',
      whereArgs: [_formatDate(date)],
      orderBy: 'updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> getFavorites() async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> getByCategory(String category) async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> getByMood(String mood) async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'mood = ?',
      whereArgs: [mood],
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> getByType(String entryType) async {
    final db = await _databaseProvider();

    final result = await db.query(
      'diary_entries',
      where: 'entry_type = ?',
      whereArgs: [entryType],
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  Future<DiaryEntry> create({
    required String title,
    required String content,
    DateTime? entryDate,
    String? mood,
    String category = 'Без категории',
    String entryType = 'diary',
    bool isFavorite = false,
    List<String> tags = const [],
  }) async {
    final db = await _databaseProvider();
    final now = DateTime.now();

    final entry = DiaryEntry(
      id: _uuid.v4(),
      title: title.trim(),
      content: content,
      entryDate: entryDate ?? now,
      createdAt: now,
      updatedAt: now,
      mood: mood,
      category: category,
      entryType: entryType,
      isFavorite: isFavorite,
      tags: tags,
    );

    await db.insert(
      'diary_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return entry;
  }

  Future<void> update(DiaryEntry entry) async {
    final db = await _databaseProvider();

    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await db.update(
      'diary_entries',
      updatedEntry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> toggleFavorite(String id) async {
    final db = await _databaseProvider();

    await db.rawUpdate(
      '''
      UPDATE diary_entries
      SET is_favorite = CASE
        WHEN is_favorite = 1 THEN 0
        ELSE 1
      END,
      updated_at = ?
      WHERE id = ?
      ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseProvider();

    await db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCount() async {
    final db = await _databaseProvider();

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM diary_entries',
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getFavoritesCount() async {
    final db = await _databaseProvider();

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM diary_entries WHERE is_favorite = 1',
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getCountByDate(DateTime date) async {
    final db = await _databaseProvider();

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM diary_entries
      WHERE entry_date = ?
      ''',
      [_formatDate(date)],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<DiaryEntry>> search(String query) async {
    final db = await _databaseProvider();
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return getAll();
    }

    final result = await db.query(
      'diary_entries',
      where: '''
        title LIKE ?
        OR content LIKE ?
        OR tags LIKE ?
      ''',
      whereArgs: [
        '%$normalizedQuery%',
        '%$normalizedQuery%',
        '%$normalizedQuery%',
      ],
      orderBy: 'entry_date DESC, updated_at DESC',
    );

    return result.map(DiaryEntry.fromMap).toList();
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
