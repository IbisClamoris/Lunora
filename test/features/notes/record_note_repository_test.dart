import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/features/notes/models/record_note.dart';
import 'package:lunora/features/notes/repositories/record_note_repository.dart';

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT,
            source_module TEXT,
            source_record_id TEXT,
            tags TEXT NOT NULL DEFAULT '[]',
            is_pinned INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordNoteRepository', () {
    late Database db;
    late RecordNoteRepository repository;

    setUp(() async {
      db = await _openDatabase();
      repository = RecordNoteRepository.forTesting(databaseProvider: () async => db);
    });

    tearDown(() async => db.close());

    test('creates and retrieves notes only for the requested record', () async {
      await repository.create(
        title: 'A favourite quote',
        content: 'A line worth remembering.',
        sourceModule: 'books',
        sourceRecordId: 'book-1',
        tags: ['quote', 'fantasy'],
        isPinned: true,
      );
      await repository.create(
        title: 'Another book',
        content: 'Separate record.',
        sourceModule: 'books',
        sourceRecordId: 'book-2',
      );

      final notes = await repository.getForRecord('books', 'book-1');
      expect(notes, hasLength(1));
      expect(notes.single.title, 'A favourite quote');
      expect(notes.single.tags, ['quote', 'fantasy']);
      expect(notes.single.isPinned, isTrue);
    });

    test('updates and deletes a note without touching other records', () async {
      final id = await repository.create(
        title: 'First',
        content: 'Draft',
        sourceModule: 'movies',
        sourceRecordId: 'movie-1',
      );
      final note = (await repository.getForRecord('movies', 'movie-1')).single;

      await repository.update(RecordNote(
        id: note.id,
        title: 'Revised',
        content: 'Final thoughts',
        sourceModule: note.sourceModule,
        sourceRecordId: note.sourceRecordId,
        tags: ['review'],
        isPinned: true,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      ));

      final updated = (await repository.getForRecord('movies', 'movie-1')).single;
      expect(updated.id, id);
      expect(updated.title, 'Revised');
      expect(updated.content, 'Final thoughts');
      expect(updated.tags, ['review']);
      expect(updated.isPinned, isTrue);

      await repository.delete(updated);
      expect(await repository.getForRecord('movies', 'movie-1'), isEmpty);
    });
  });
}
