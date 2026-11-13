import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/database.dart';
import '../models/wishlist_entry.dart';

class WishlistRepository {
  Future<Database> get _database async {
    return LunoraDatabase.instance.database;
  }

  Future<List<WishlistEntry>> getAll({
    bool? isPurchased,
    String? category,
  }) async {
    final db = await _database;
    final conditions = <String>[];
    final arguments = <Object?>[];

    if (isPurchased != null) {
      conditions.add('is_purchased = ?');
      arguments.add(isPurchased ? 1 : 0);
    }

    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      arguments.add(category);
    }

    final rows = await db.query(
      'wishlist_entries',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : arguments,
      orderBy: '''
        is_purchased ASC,
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'normal' THEN 1
          WHEN 'low' THEN 2
          ELSE 3
        END ASC,
        sort_order ASC,
        created_at DESC
      ''',
    );

    return rows.map(WishlistEntry.fromMap).toList();
  }

  Future<WishlistEntry?> getById(String id) async {
    final db = await _database;

    final rows = await db.query(
      'wishlist_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return WishlistEntry.fromMap(rows.first);
  }

  Future<void> create(WishlistEntry entry) async {
    final db = await _database;

    await db.insert(
      'wishlist_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> update(WishlistEntry entry) async {
    final db = await _database;

    await db.update(
      'wishlist_entries',
      entry.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete('wishlist_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPurchased(String id, {required bool isPurchased}) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'wishlist_entries',
      {
        'is_purchased': isPurchased ? 1 : 0,
        'purchased_at': isPurchased ? now : null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getCategories() async {
    final db = await _database;

    final rows = await db.rawQuery('''
      SELECT DISTINCT category
      FROM wishlist_entries
      WHERE category != ''
      ORDER BY category COLLATE NOCASE ASC
    ''');

    return rows.map((row) => row['category'] as String).toList();
  }
}
