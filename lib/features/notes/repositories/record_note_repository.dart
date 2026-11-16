import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/record_note.dart';

typedef NoteDatabaseProvider = Future<Database> Function();

class RecordNoteRepository {
  RecordNoteRepository._({NoteDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  RecordNoteRepository.forTesting({required NoteDatabaseProvider databaseProvider})
    : _databaseProvider = databaseProvider;

  static final RecordNoteRepository instance = RecordNoteRepository._();
  static const Uuid _uuid = Uuid();

  final NoteDatabaseProvider _databaseProvider;
  Future<Database> get _database => _databaseProvider();

  Future<List<RecordNote>> getForRecord(
    String sourceModule,
    String sourceRecordId,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'notes',
      where: 'source_module = ? AND source_record_id = ?',
      whereArgs: [sourceModule, sourceRecordId],
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(RecordNote.fromMap).toList();
  }

  Future<String> create({
    required String title,
    required String content,
    required String sourceModule,
    required String sourceRecordId,
    List<String> tags = const [],
    bool isPinned = false,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.insert('notes', {
      'id': id,
      'title': title.trim(),
      'content': content,
      'source_module': sourceModule,
      'source_record_id': sourceRecordId,
      'tags': RecordNote(
        id: id,
        title: title,
        content: content,
        sourceModule: sourceModule,
        sourceRecordId: sourceRecordId,
        tags: tags,
        isPinned: isPinned,
        createdAt: now,
        updatedAt: now,
      ).toMap()['tags'],
      'is_pinned': isPinned ? 1 : 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return id;
  }

  Future<void> update(RecordNote note) async {
    final db = await _database;
    await db.update(
      'notes',
      {
        'title': note.title.trim(),
        'content': note.content,
        'tags': RecordNote(
          id: note.id,
          title: note.title,
          content: note.content,
          sourceModule: note.sourceModule,
          sourceRecordId: note.sourceRecordId,
          tags: note.tags,
          isPinned: note.isPinned,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
        ).toMap()['tags'],
        'is_pinned': note.isPinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND source_module = ? AND source_record_id = ?',
      whereArgs: [note.id, note.sourceModule, note.sourceRecordId],
    );
  }

  Future<void> delete(RecordNote note) async {
    final db = await _database;
    await db.delete(
      'notes',
      where: 'id = ? AND source_module = ? AND source_record_id = ?',
      whereArgs: [note.id, note.sourceModule, note.sourceRecordId],
    );
  }
}
