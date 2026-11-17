import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lunora/features/record_links/repositories/record_link_repository.dart';

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE record_links (
            id TEXT PRIMARY KEY,
            source_module TEXT NOT NULL,
            source_record_id TEXT NOT NULL,
            target_module TEXT NOT NULL,
            target_record_id TEXT NOT NULL,
            relation_type TEXT NOT NULL DEFAULT 'related',
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            CHECK (source_module != target_module OR source_record_id != target_record_id),
            UNIQUE (source_module, source_record_id, target_module, target_record_id, relation_type)
          )
        ''');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordLinkRepository', () {
    late Database db;
    late RecordLinkRepository repository;

    setUp(() async {
      db = await _openDatabase();
      repository = RecordLinkRepository.forTesting(databaseProvider: () async => db);
    });

    tearDown(() async => db.close());

    test('returns the same link from both records', () async {
      final id = await repository.create(
        sourceModule: 'books',
        sourceRecordId: 'book-1',
        targetModule: 'movies',
        targetRecordId: 'movie-1',
        note: 'Film adaptation',
      );

      final fromBook = await repository.getForRecord('books', 'book-1');
      final fromMovie = await repository.getForRecord('movies', 'movie-1');

      expect(fromBook, hasLength(1));
      expect(fromMovie, hasLength(1));
      expect(fromBook.single.link.id, id);
      expect(fromMovie.single.link.id, id);
      expect(fromBook.single.module, 'movies');
      expect(fromBook.single.recordId, 'movie-1');
      expect(fromMovie.single.module, 'books');
      expect(fromMovie.single.recordId, 'book-1');
      expect(fromMovie.single.link.note, 'Film adaptation');
    });

    test('does not create a duplicate when linked from the other side', () async {
      final first = await repository.create(
        sourceModule: 'books',
        sourceRecordId: 'book-1',
        targetModule: 'movies',
        targetRecordId: 'movie-1',
      );
      final second = await repository.create(
        sourceModule: 'movies',
        sourceRecordId: 'movie-1',
        targetModule: 'books',
        targetRecordId: 'book-1',
      );

      expect(second, first);
      expect(await db.query('record_links'), hasLength(1));
    });

    test('rejects self-links and removes a link without deleting records', () async {
      await expectLater(
        repository.create(
          sourceModule: 'books',
          sourceRecordId: 'book-1',
          targetModule: 'books',
          targetRecordId: 'book-1',
        ),
        throwsArgumentError,
      );

      final id = await repository.create(
        sourceModule: 'books',
        sourceRecordId: 'book-1',
        targetModule: 'books',
        targetRecordId: 'book-2',
      );
      await repository.delete(id);

      expect(await repository.getForRecord('books', 'book-1'), isEmpty);
      expect(await repository.getForRecord('books', 'book-2'), isEmpty);
    });
  });
}
