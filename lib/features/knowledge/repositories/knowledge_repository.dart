import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/knowledge_entry.dart';

typedef KnowledgeDatabaseProvider = Future<Database> Function();

class KnowledgeRepository {
  KnowledgeRepository._({KnowledgeDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final KnowledgeRepository instance = KnowledgeRepository._();

  final KnowledgeDatabaseProvider _databaseProvider;
  final Uuid _uuid = const Uuid();

  static const String sourceModule = 'knowledge';

  Future<Database> get _database => _databaseProvider();

  Future<List<KnowledgeEntry>> getAll({
    String? searchQuery,
    String? category,
    bool favoritesOnly = false,
    String sortBy = 'updated_at',
    bool descending = true,
  }) async {
    final db = await _database;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(k.title LIKE ? OR k.content LIKE ? OR k.tags LIKE ?)');
      final query = '%${searchQuery.trim()}%';
      arguments.addAll([query, query, query]);
    }

    if (category != null && category.isNotEmpty) {
      conditions.add('k.category = ?');
      arguments.add(category);
    }

    if (favoritesOnly) {
      conditions.add('f.id IS NOT NULL');
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    const allowedSortColumns = {
      'title',
      'created_at',
      'updated_at',
      'sort_order',
      'category',
    };

    final safeSortBy = allowedSortColumns.contains(sortBy)
        ? sortBy
        : 'updated_at';

    final direction = descending ? 'DESC' : 'ASC';

    final rows = await db.rawQuery(
      '''
      SELECT
        k.*,
        CASE WHEN f.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite
      FROM knowledge_entries k
      LEFT JOIN favorites f
        ON f.source_module = ?
        AND f.source_record_id = k.id
      $where
      ORDER BY k.$safeSortBy $direction, k.title COLLATE NOCASE ASC
      ''',
      [sourceModule, ...arguments],
    );

    return rows.map((row) {
      return KnowledgeEntry.fromMap(row, isFavorite: row['is_favorite'] == 1);
    }).toList();
  }

  Future<KnowledgeEntry?> getById(String id) async {
    final db = await _database;

    final rows = await db.rawQuery(
      '''
      SELECT
        k.*,
        CASE WHEN f.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite
      FROM knowledge_entries k
      LEFT JOIN favorites f
        ON f.source_module = ?
        AND f.source_record_id = k.id
      WHERE k.id = ?
      LIMIT 1
      ''',
      [sourceModule, id],
    );

    if (rows.isEmpty) return null;

    return KnowledgeEntry.fromMap(
      rows.first,
      isFavorite: rows.first['is_favorite'] == 1,
    );
  }

  Future<KnowledgeEntry> create({
    required String title,
    String content = '',
    String category = 'Другое',
    List<String> tags = const [],
    String? sourceUrl,
  }) async {
    final db = await _database;
    final now = DateTime.now();

    final entry = KnowledgeEntry(
      id: _uuid.v4(),
      title: title.trim(),
      content: content,
      category: category,
      tags: tags,
      sourceUrl: _normalizeUrl(sourceUrl),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'knowledge_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return entry;
  }

  Future<void> update(KnowledgeEntry entry) async {
    final db = await _database;

    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await db.update(
      'knowledge_entries',
      updatedEntry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.transaction((txn) async {
      await txn.delete('knowledge_entries', where: 'id = ?', whereArgs: [id]);

      await txn.delete(
        'favorites',
        where: 'source_module = ? AND source_record_id = ?',
        whereArgs: [sourceModule, id],
      );
    });
  }

  Future<void> toggleFavorite(String id, {required bool isFavorite}) async {
    final db = await _database;

    if (isFavorite) {
      await db.insert('favorites', {
        'id': _uuid.v4(),
        'source_module': sourceModule,
        'source_record_id': id,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'favorites',
        where: 'source_module = ? AND source_record_id = ?',
        whereArgs: [sourceModule, id],
      );
    }
  }

  Future<int> getCount({String? category}) async {
    final db = await _database;

    final result = await db.rawQuery(
      category == null ? 'SELECT COUNT(*) AS total FROM knowledge_entries' : 'SELECT COUNT(*) AS total FROM knowledge_entries WHERE category = ?',
      category == null ? [] : [category],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getFavoritesCount() async {
    final db = await _database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM favorites f
      INNER JOIN knowledge_entries k ON k.id = f.source_record_id
      WHERE f.source_module = ?
      ''',
      [sourceModule],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  String? _normalizeUrl(String? value) {
    final url = value?.trim();

    if (url == null || url.isEmpty) return null;

    if (url.startsWith('https://') || url.startsWith('http://')) {
      return url;
    }

    return 'https://$url';
  }
}
