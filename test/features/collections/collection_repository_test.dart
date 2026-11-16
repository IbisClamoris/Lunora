import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/core/database/database_migrations.dart';
import 'package:lunora/features/collections/repositories/collection_repository.dart';

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE notes (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT,
          source_module TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )''');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CollectionRepository', () {
    late Database db;
    late CollectionRepository repository;

    setUp(() async {
      db = await _openDatabase();
      await DatabaseMigrations.migrate(db, 1, 26);
      repository = CollectionRepository.forTesting(() async => db);
    });
    tearDown(() => db.close());

    test('creates collection and rejects blank names', () async {
      final entry = await repository.create(name: '  Reading list  ');
      expect(entry.name, 'Reading list');
      expect(entry.sortOrder, 0);
      await expectLater(repository.create(name: '  '), throwsArgumentError);
    });

    test('adds records once and counts collection items', () async {
      final collection = await repository.create(name: 'Favorites');
      expect(await repository.addRecord(collectionId: collection.id,
          recordModule: 'books', recordId: 'book-1'), isTrue);
      expect(await repository.addRecord(collectionId: collection.id,
          recordModule: 'books', recordId: 'book-1'), isFalse);
      expect((await repository.getById(collection.id))!.itemCount, 1);
      expect((await repository.getItems(collection.id)).single.recordId, 'book-1');
    });

    test('removes records and cascades collection deletion', () async {
      final collection = await repository.create(name: 'Watch later');
      await repository.addRecord(collectionId: collection.id,
          recordModule: 'movies', recordId: 'movie-1');
      await repository.removeRecord(collectionId: collection.id,
          recordModule: 'movies', recordId: 'movie-1');
      expect(await repository.getItems(collection.id), isEmpty);
      await repository.addRecord(collectionId: collection.id,
          recordModule: 'movies', recordId: 'movie-2');
      await repository.delete(collection.id);
      expect(await db.query('collection_items'), isEmpty);
    });

    test('updates collection metadata and item notes', () async {
      final collection = await repository.create(name: 'Ideas');
      await repository.update(collection.copyWith(
          name: 'Inspiration', description: 'Things to revisit'));
      await repository.addRecord(collectionId: collection.id,
          recordModule: 'knowledge', recordId: 'entry-1');
      await repository.updateItemNote(collectionId: collection.id,
          recordModule: 'knowledge', recordId: 'entry-1',
          note: 'Useful reference');
      expect((await repository.getById(collection.id))!.name, 'Inspiration');
      expect((await repository.getItems(collection.id)).single.note, 'Useful reference');
    });
  });
}
