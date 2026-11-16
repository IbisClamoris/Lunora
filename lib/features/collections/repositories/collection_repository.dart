import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/collection_entry.dart';

typedef CollectionDatabaseProvider = Future<Database> Function();

class CollectionRepository {
  CollectionRepository._({CollectionDatabaseProvider? databaseProvider})
      : _databaseProvider =
            databaseProvider ?? (() => LunoraDatabase.instance.database);

  @visibleForTesting
  CollectionRepository.forTesting(CollectionDatabaseProvider databaseProvider)
      : _databaseProvider = databaseProvider;

  static final CollectionRepository instance = CollectionRepository._();
  final CollectionDatabaseProvider _databaseProvider;
  static const Uuid _uuid = Uuid();

  Future<Database> get _database => _databaseProvider();

  Future<List<CollectionEntry>> getAll() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT c.*, COUNT(i.id) AS item_count
      FROM collections c LEFT JOIN collection_items i ON i.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.sort_order ASC, c.updated_at DESC, c.name COLLATE NOCASE ASC
    ''');
    return rows.map(CollectionEntry.fromMap).toList();
  }

  Future<CollectionEntry?> getById(String id) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT c.*, COUNT(i.id) AS item_count
      FROM collections c LEFT JOIN collection_items i ON i.collection_id = c.id
      WHERE c.id = ? GROUP BY c.id LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : CollectionEntry.fromMap(rows.first);
  }

  Future<List<CollectionItem>> getItems(String collectionId) async {
    final db = await _database;
    final rows = await db.query('collection_items',
        where: 'collection_id = ?', whereArgs: [collectionId],
        orderBy: 'sort_order ASC, added_at ASC');
    return rows.map(CollectionItem.fromMap).toList();
  }

  Future<CollectionEntry> create({
    required String name, String description = '', String? coverPath, int? colorValue,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Collection name cannot be empty.');
    }
    final db = await _database;
    final now = DateTime.now();
    final entry = CollectionEntry(
      id: _uuid.v4(), name: normalizedName, description: description.trim(),
      coverPath: coverPath, colorValue: colorValue,
      sortOrder: await _nextSortOrder(db), createdAt: now, updatedAt: now,
    );
    await db.insert('collections', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
    return entry;
  }

  Future<void> update(CollectionEntry entry) async {
    final name = entry.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(entry.name, 'name', 'Collection name cannot be empty.');
    }
    final db = await _database;
    await db.update('collections',
        entry.copyWith(name: name, updatedAt: DateTime.now()).toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> addRecord({
    required String collectionId, required String recordModule,
    required String recordId, String note = '',
  }) async {
    final module = recordModule.trim();
    final record = recordId.trim();
    if (module.isEmpty || record.isEmpty) {
      throw ArgumentError('Record module and ID must not be empty.');
    }
    final db = await _database;
    final exists = await db.query('collections', columns: ['id'],
        where: 'id = ?', whereArgs: [collectionId], limit: 1);
    if (exists.isEmpty) throw StateError('Collection does not exist: $collectionId');
    final now = DateTime.now();
    final inserted = await db.insert('collection_items', {
      'id': _uuid.v4(), 'collection_id': collectionId,
      'record_module': module, 'record_id': record, 'note': note.trim(),
      'sort_order': await _nextItemSortOrder(db, collectionId),
      'added_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (inserted == 0) return false;
    await db.update('collections', {'updated_at': now.toIso8601String()},
        where: 'id = ?', whereArgs: [collectionId]);
    return true;
  }

  Future<void> removeRecord({
    required String collectionId, required String recordModule, required String recordId,
  }) async {
    final db = await _database;
    await db.delete('collection_items',
        where: 'collection_id = ? AND record_module = ? AND record_id = ?',
        whereArgs: [collectionId, recordModule, recordId]);
    await db.update('collections', {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [collectionId]);
  }

  Future<void> updateItemNote({
    required String collectionId, required String recordModule,
    required String recordId, required String note,
  }) async {
    final db = await _database;
    await db.update('collection_items', {'note': note.trim()},
        where: 'collection_id = ? AND record_module = ? AND record_id = ?',
        whereArgs: [collectionId, recordModule, recordId]);
  }

  Future<void> reorderItems(String collectionId, List<String> itemIds) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (var index = 0; index < itemIds.length; index++) {
        await txn.update('collection_items', {'sort_order': index},
            where: 'id = ? AND collection_id = ?',
            whereArgs: [itemIds[index], collectionId]);
      }
      await txn.update('collections', {'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [collectionId]);
    });
  }

  Future<int> _nextSortOrder(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM collections');
    return (rows.first['next_order'] as num).toInt();
  }

  Future<int> _nextItemSortOrder(DatabaseExecutor db, String collectionId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM collection_items WHERE collection_id = ?',
      [collectionId]);
    return (rows.first['next_order'] as num).toInt();
  }
}
