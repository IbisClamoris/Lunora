import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/record_link.dart';

typedef RecordLinkDatabaseProvider = Future<Database> Function();

class RecordLinkRepository {
  RecordLinkRepository._({RecordLinkDatabaseProvider? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => LunoraDatabase.instance.database);

  RecordLinkRepository.forTesting({required RecordLinkDatabaseProvider databaseProvider})
    : _databaseProvider = databaseProvider;

  static final RecordLinkRepository instance = RecordLinkRepository._();
  static const Uuid _uuid = Uuid();
  final RecordLinkDatabaseProvider _databaseProvider;
  Future<Database> get _database => _databaseProvider();

  Future<List<LinkedRecord>> getForRecord(String module, String recordId) async {
    final db = await _database;
    final outgoing = await db.query('record_links',
      where: 'source_module = ? AND source_record_id = ?',
      whereArgs: [module, recordId], orderBy: 'created_at DESC');
    final incoming = await db.query('record_links',
      where: 'target_module = ? AND target_record_id = ?',
      whereArgs: [module, recordId], orderBy: 'created_at DESC');
    return [
      ...outgoing.map((row) {
        final link = RecordLink.fromMap(row);
        return LinkedRecord(link: link, module: link.targetModule, recordId: link.targetRecordId);
      }),
      ...incoming.map((row) {
        final link = RecordLink.fromMap(row);
        return LinkedRecord(link: link, module: link.sourceModule, recordId: link.sourceRecordId);
      }),
    ]..sort((a, b) => b.link.createdAt.compareTo(a.link.createdAt));
  }

  Future<String> create({
    required String sourceModule, required String sourceRecordId,
    required String targetModule, required String targetRecordId,
    String relationType = 'related', String note = '',
  }) async {
    if (sourceModule == targetModule && sourceRecordId == targetRecordId) {
      throw ArgumentError('A record cannot be linked to itself.');
    }
    final sourceKey = '$sourceModule:$sourceRecordId';
    final targetKey = '$targetModule:$targetRecordId';
    final reverse = sourceKey.compareTo(targetKey) > 0;
    final db = await _database;
    final id = _uuid.v4();
    await db.insert('record_links', {
      'id': id,
      'source_module': reverse ? targetModule : sourceModule,
      'source_record_id': reverse ? targetRecordId : sourceRecordId,
      'target_module': reverse ? sourceModule : targetModule,
      'target_record_id': reverse ? sourceRecordId : targetRecordId,
      'relation_type': relationType, 'note': note.trim(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query('record_links', columns: ['id'],
      where: '''(source_module = ? AND source_record_id = ? AND target_module = ? AND target_record_id = ?)
        OR (source_module = ? AND source_record_id = ? AND target_module = ? AND target_record_id = ?)''',
      whereArgs: [sourceModule, sourceRecordId, targetModule, targetRecordId,
        targetModule, targetRecordId, sourceModule, sourceRecordId], limit: 1);
    return rows.isEmpty ? id : rows.first['id'] as String;
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('record_links', where: 'id = ?', whereArgs: [id]);
  }
}
